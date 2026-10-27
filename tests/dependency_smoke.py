"""Credential-free smoke checks for the workshop's locked Python environments."""

from __future__ import annotations

import argparse
import asyncio
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from datetime import datetime, timedelta, timezone
import importlib
import json
import os
from pathlib import Path
import socket
import sys
from unittest.mock import patch
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from starlette.types import ASGIApp


ROOT = Path(__file__).resolve().parents[1]
PROJECTS = {
    "base": "camps/base-camp/secure-server",
    "identity": "camps/camp1-identity/secure-server",
    "sherpa": "camps/camp2-gateway/servers/sherpa-mcp-server",
    "trail": "camps/camp2-gateway/servers/trail-api",
    "headers": "camps/camp2-gateway/samples/mcp-custom-headers",
    "foundry": "camps/camp2-gateway/samples/foundry-tools",
}


@asynccontextmanager
async def serve(app: ASGIApp) -> AsyncIterator[str]:
    import uvicorn

    with socket.socket() as listener:
        listener.bind(("127.0.0.1", 0))
        server = uvicorn.Server(uvicorn.Config(app, log_level="error"))
        task = asyncio.create_task(server.serve(sockets=[listener]))
        try:
            async with asyncio.timeout(10):
                while not server.started:
                    if task.done():
                        await task
                        raise RuntimeError("Server exited before becoming ready")
                    await asyncio.sleep(0.05)
            yield f"http://127.0.0.1:{listener.getsockname()[1]}"
        finally:
            server.should_exit = True
            await asyncio.wait_for(task, timeout=10)


def signing_key() -> tuple[bytes, bytes]:
    from cryptography.hazmat.primitives import serialization
    from cryptography.hazmat.primitives.asymmetric import rsa

    private = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    pem = private.private_bytes(
        serialization.Encoding.PEM,
        serialization.PrivateFormat.PKCS8,
        serialization.NoEncryption(),
    )
    public = private.public_key().public_bytes(
        serialization.Encoding.PEM, serialization.PublicFormat.SubjectPublicKeyInfo
    )
    return pem, public


async def sherpa() -> None:
    from fastmcp import Client
    from opentelemetry.trace.propagation.tracecontext import TraceContextTextMapPropagator
    from src.server import mcp

    propagator = TraceContextTextMapPropagator()
    carrier = {"traceparent": "00-12345678901234567890123456789012-1234567890123456-01"}
    outgoing = {}
    propagator.inject(outgoing, context=propagator.extract(carrier))
    assert outgoing == carrier, outgoing
    async with serve(mcp.http_app(path="/mcp", transport="streamable-http")) as url:
        async with Client(f"{url}/mcp") as client:
            tools = await client.list_tools()
            assert {tool.name for tool in tools} == {
                "get_weather", "check_trail_conditions", "get_gear_recommendations"
            }
            for name, arguments, field, expected in (
                ("get_weather", {"location": "summit"}, "temp_f", 28),
                ("check_trail_conditions", {"trail_id": "ridge-walk"}, "status", "limited"),
                ("get_gear_recommendations", {"condition_type": "winter"}, "condition_type", "winter"),
            ):
                result = await client.call_tool(name, arguments)
                assert json.loads(result.content[0].text)[field] == expected


async def base() -> None:
    import httpx
    from fastmcp import Client
    from fastmcp.client.auth import BearerAuth
    from fastmcp.exceptions import ToolError
    from src.server import mcp, REQUIRED_TOKEN

    async with serve(mcp.http_app(path="/mcp", transport="streamable-http")) as url:
        async with httpx.AsyncClient(base_url=url) as http:
            for token in (None, "invalid-smoke-token"):
                headers = {"Authorization": f"Bearer {token}"} if token else {}
                assert (await http.get("/mcp", headers=headers)).status_code == 401
        async with Client(f"{url}/mcp", auth=BearerAuth(REQUIRED_TOKEN)) as client:
            own = await client.call_tool("get_user_info", {"user_id": "user_001"})
            assert own.data["authorization_verified"] is True
            try:
                await client.call_tool("get_user_info", {"user_id": "user_002"})
            except ToolError as error:
                assert "cannot access user_002" in str(error), error
            else:
                raise AssertionError("Cross-user data access was accepted")


async def identity() -> None:
    import httpx
    import jwt
    from fastmcp import Client
    from fastmcp.client.auth import BearerAuth
    from fastmcp.server.auth.providers.jwt import JWTVerifier
    from msal.oauth2cli.assertion import JwtAssertionCreator

    os.environ["AZURE_TENANT_ID"] = "00000000-0000-0000-0000-000000000001"
    os.environ["AZURE_CLIENT_ID"] = "00000000-0000-0000-0000-000000000002"
    os.environ["RESOURCE_URL"] = "https://mcp.example.test"
    os.environ.pop("KEY_VAULT_URL", None)
    private, public = signing_key()

    def local_verifier(*, jwks_uri: str, audience: str, issuer: str) -> JWTVerifier:
        assert jwks_uri.startswith("https://login.microsoftonline.com/")
        return JWTVerifier(
            public_key=public, algorithm="RS256", audience=audience, issuer=issuer
        )

    with patch("fastmcp.server.auth.providers.jwt.JWTVerifier", side_effect=local_verifier):
        module = importlib.import_module("src.server")
    issuer = f"https://login.microsoftonline.com/{module.TENANT_ID}/v2.0"
    claims = {
        "sub": "smoke-user", "iss": issuer, "aud": module.CLIENT_ID,
        "exp": datetime.now(timezone.utc) + timedelta(minutes=5), "scope": "read",
    }
    token = jwt.encode(claims, private, algorithm="RS256")
    assertion = JwtAssertionCreator(private, "RS256").create_normal_assertion(
        audience=issuer, issuer="smoke-client"
    )
    jwt.decode(assertion, public, algorithms=["RS256"], audience=issuer, issuer="smoke-client")
    async with serve(module.app) as url:
        async with httpx.AsyncClient(base_url=url) as http:
            assert (await http.get("/health")).status_code == 200
            metadata = (await http.get("/.well-known/oauth-protected-resource")).json()
            assert metadata["resource"] == "https://mcp.example.test"
            assert metadata["authorization_servers"] == [issuer]
            changes = (
                {"exp": datetime.now(timezone.utc) - timedelta(minutes=5)},
                {"aud": "wrong-audience"}, {"iss": "https://wrong-issuer.example.test"},
            )
            invalid = [jwt.encode({**claims, **change}, private, algorithm="RS256") for change in changes]
            wrong_private, _ = signing_key()
            invalid.append(jwt.encode(claims, wrong_private, algorithm="RS256"))
            for candidate in [None, *invalid]:
                headers = {"Authorization": f"Bearer {candidate}"} if candidate else {}
                response = await http.get("/mcp", headers=headers)
                assert response.status_code == 401, response.status_code
                assert "resource_metadata=" in response.headers["WWW-Authenticate"]
        async with Client(f"{url}/mcp", auth=BearerAuth(token)) as client:
            tools = await client.list_tools()
            assert "get_user_info" in {tool.name for tool in tools}
            result = await client.call_tool("get_user_info", {"user_id": "user_001"})
            assert result.data["server_type"] == "SECURE"


async def trail() -> None:
    import httpx
    from src.main import app

    async with serve(app) as url:
        async with httpx.AsyncClient(base_url=url) as client:
            assert (await client.get("/health")).json()["status"] == "healthy"
            trails = (await client.get("/trails")).json()
            assert trails
            trail_id = trails[0]["id"]
            for path in (f"/trails/{trail_id}", f"/trails/{trail_id}/conditions"):
                assert (await client.get(path)).status_code == 200, path
            assert (await client.get("/trails/not-a-trail")).status_code == 404


async def headers() -> None:
    import httpx
    import direct_mcp_client as module

    requests = []

    def handle(request: httpx.Request) -> httpx.Response:
        requests.append(request)
        payload = json.loads(request.content)
        results = {
            "initialize": {"serverInfo": {"name": "smoke", "version": "1"}},
            "tools/list": {"tools": [{"name": "get_weather"}]},
            "tools/call": {"content": [{"type": "text", "text": "sunny"}]},
        }
        return httpx.Response(
            200, headers={"mcp-session-id": "smoke-session"},
            json={"jsonrpc": "2.0", "id": payload["id"], "result": results[payload["method"]]},
        )

    real_client = httpx.AsyncClient
    with patch.object(
        module.httpx, "AsyncClient",
        side_effect=lambda **kwargs: real_client(**kwargs, transport=httpx.MockTransport(handle)),
    ):
        client = module.MCPClient(
            "https://mcp.example.test/mcp", custom_headers={"x-customer-id": "smoke"}
        )
        assert (await client.list_tools())[0]["name"] == "get_weather"
        assert (await client.call_tool("get_weather"))[0]["text"] == "sunny"
    assert len(requests) == 3
    assert all(request.headers["x-customer-id"] == "smoke" for request in requests)
    assert all(request.headers["mcp-session-id"] == "smoke-session" for request in requests[1:])


async def foundry() -> None:
    import foundry_tools as module

    tool = module.MCPTool(
        server_label="sherpa", server_url="https://mcp.example.test/mcp",
        require_approval="always", project_connection_id=module.CONNECTION_NAME,
    )
    definition = module.PromptAgentDefinition(
        model=module.MODEL_DEPLOYMENT_NAME, instructions="Use Sherpa tools.", tools=[tool]
    )
    assert definition.tools[0].server_label == "sherpa"
    with patch.object(sys, "argv", ["foundry_tools.py", "--help"]):
        try:
            module.main()
        except SystemExit as result:
            assert result.code == 0, result.code
        else:
            raise AssertionError("CLI help did not exit")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("project", choices=PROJECTS)
    project = parser.parse_args().project
    sys.path.insert(0, str(ROOT / PROJECTS[project]))
    asyncio.run(globals()[project]())
    print(f"PASS: {project} dependency smoke checks")
