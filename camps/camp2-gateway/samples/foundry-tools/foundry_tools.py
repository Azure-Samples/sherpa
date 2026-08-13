#!/usr/bin/env python3

import argparse
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any

from azure.ai.projects import AIProjectClient
from azure.ai.projects.models import MCPTool, PromptAgentDefinition
from azure.core.exceptions import HttpResponseError, ResourceNotFoundError
from azure.identity import AzureCliCredential
from openai.types.responses.response_input_param import (
    McpApprovalResponse,
    ResponseInputParam,
)

SAMPLE_DIR = Path(__file__).resolve().parent
CAMP_DIR = SAMPLE_DIR.parents[1]
STATE_FILE = SAMPLE_DIR / ".state.json"

FOUNDRY_ACCOUNT_NAME = os.getenv("FOUNDRY_ACCOUNT_NAME", "aif-camp2")
FOUNDRY_PROJECT_NAME = os.getenv("FOUNDRY_PROJECT_NAME", "camp2-project")
MODEL_DEPLOYMENT_NAME = os.getenv("FOUNDRY_MODEL_DEPLOYMENT_NAME", "gpt-5.4-mini")
AGENT_NAME = "sherpa-agent"
AGENT_DISPLAY_NAME = "Sherpa Agent"
CONNECTION_NAME = "SherpaMCPServer"
SAMPLE_OWNER = "sherpa-foundry-tools"
API_VERSION_PROJECT = "2025-06-01"
API_VERSION_CONNECTION = "2025-04-01-preview"
API_VERSION_API_CENTER = "2024-06-01-preview"
API_VERSION_APIM = "2024-05-01"


def run(
    args: list[str],
    *,
    cwd: Path | None = None,
    check: bool = True,
    input_text: str | None = None,
) -> str:
    result = subprocess.run(
        args,
        cwd=cwd,
        check=False,
        capture_output=True,
        text=True,
        input=input_text,
    )
    if check and result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip()
        raise RuntimeError(f"{' '.join(args[:3])} failed: {detail}")
    return result.stdout.strip()


def az_json(args: list[str]) -> Any:
    output = run(["az", *args, "--output", "json"])
    return json.loads(output.lstrip("\ufeff")) if output else None


def az_tsv(args: list[str]) -> str:
    return run(["az", *args, "--output", "tsv"])


def azd_value(name: str) -> str:
    value = run(["azd", "env", "get-value", name], cwd=CAMP_DIR)
    if not value:
        raise RuntimeError(f"{name} is not set in the Camp 2 azd environment.")
    return value


def put_arm_resource(uri: str, body: dict[str, Any]) -> dict[str, Any]:
    with tempfile.NamedTemporaryFile(
        mode="w", suffix=".json", delete=False, encoding="utf-8"
    ) as handle:
        json.dump(body, handle)
        body_path = Path(handle.name)
    body_path.chmod(0o600)
    try:
        output = run(
            [
                "az",
                "rest",
                "--method",
                "put",
                "--uri",
                uri,
                "--body",
                f"@{body_path}",
                "--output",
                "json",
            ]
        )
        try:
            return json.loads(output.lstrip("\ufeff")) if output else {}
        except json.JSONDecodeError:
            return {"raw": output.lstrip("\ufeff")}
    finally:
        body_path.unlink(missing_ok=True)


def get_context() -> dict[str, str]:
    account = az_json(["account", "show"])
    tenant_id = account["tenantId"]
    subscription_id = account["id"]
    resource_group = azd_value("AZURE_RESOURCE_GROUP")
    api_center_name = azd_value("API_CENTER_NAME")
    mcp_app_client_id = azd_value("MCP_APP_CLIENT_ID")

    project_id = (
        f"/subscriptions/{subscription_id}/resourceGroups/{resource_group}"
        f"/providers/Microsoft.CognitiveServices/accounts/{FOUNDRY_ACCOUNT_NAME}"
        f"/projects/{FOUNDRY_PROJECT_NAME}"
    )
    project_uri = (
        f"https://management.azure.com{project_id}"
        f"?api-version={API_VERSION_PROJECT}"
    )
    project = az_json(["rest", "--method", "get", "--uri", project_uri])
    project_endpoint = project["properties"]["endpoints"]["AI Foundry API"]

    api_center_id = az_tsv(
        [
            "apic",
            "show",
            "--resource-group",
            resource_group,
            "--name",
            api_center_name,
            "--query",
            "id",
        ]
    )
    deployment_uri = (
        f"https://management.azure.com{api_center_id}/workspaces/default"
        f"/apis/sherpa-mcp/deployments/camp2-apim"
        f"?api-version={API_VERSION_API_CENTER}"
    )
    sherpa_url = az_tsv(
        [
            "rest",
            "--method",
            "get",
            "--uri",
            deployment_uri,
            "--query",
            "properties.server.runtimeUri[0]",
        ]
    )
    if not sherpa_url.startswith("https://"):
        raise RuntimeError("API Center did not return a valid Sherpa runtime URL.")

    return {
        "tenantId": tenant_id,
        "subscriptionId": subscription_id,
        "resourceGroup": resource_group,
        "apiCenterName": api_center_name,
        "apiCenterId": api_center_id,
        "mcpAppClientId": mcp_app_client_id,
        "projectId": project_id,
        "projectEndpoint": project_endpoint,
        "sherpaUrl": sherpa_url,
        "apimName": azd_value("APIM_NAME"),
    }


def ensure_foundry_role(context: dict[str, str]) -> None:
    user_object_id = az_tsv(["ad", "signed-in-user", "show", "--query", "id"])
    assignments = az_json(
        [
            "role",
            "assignment",
            "list",
            "--assignee",
            user_object_id,
            "--scope",
            context["projectId"],
            "--query",
            "[?roleDefinitionName=='Foundry User']",
        ]
    )
    if assignments:
        return
    run(
        [
            "az",
            "role",
            "assignment",
            "create",
            "--assignee-object-id",
            user_object_id,
            "--assignee-principal-type",
            "User",
            "--role",
            "Foundry User",
            "--scope",
            context["projectId"],
            "--output",
            "none",
        ]
    )


def connection_uri(context: dict[str, str]) -> str:
    return (
        f"https://management.azure.com{context['projectId']}"
        f"/connections/{CONNECTION_NAME}?api-version={API_VERSION_CONNECTION}"
    )


def configure_catalog_connection(context: dict[str, str]) -> dict[str, Any]:
    uri = connection_uri(context)
    existing = run(
        ["az", "rest", "--method", "get", "--uri", uri, "--output", "json"],
        check=False,
    )
    if existing:
        existing_properties = json.loads(existing)["properties"]
        sample_owned = (
            existing_properties.get("metadata", {}).get("sampleOwner") == SAMPLE_OWNER
        )
        if existing_properties.get("authType", "None") != "None" and not sample_owned:
            raise RuntimeError(
                f"{CONNECTION_NAME} already has authentication configured. "
                "Cleanup or choose a different project before running this sample."
            )
        original_connection = {
            "existed": True,
            "properties": {
                "authType": "None" if sample_owned else existing_properties.get("authType", "None"),
                "category": existing_properties.get("category", "RemoteTool"),
                "target": existing_properties.get("target", context["sherpaUrl"]),
                "metadata": {
                    key: value
                    for key, value in existing_properties.get("metadata", {}).items()
                    if key != "sampleOwner"
                },
            },
        }
    else:
        original_connection = {"existed": False}

    tool_entity_id = (
        "azureml://location/swedencentral/apiCenter/"
        f"{context['apiCenterName']}/type/tools/objectId/sherpa-mcp/version/1"
    )
    body = {
        "properties": {
            "authType": "ProjectManagedIdentity",
            "category": "RemoteTool",
            "target": context["sherpaUrl"],
            "audience": context["mcpAppClientId"],
            "metadata": {
                "toolEntityId": tool_entity_id,
                "type": "catalog_MCP",
                "sampleOwner": SAMPLE_OWNER,
            },
        }
    }
    put_arm_resource(uri, body)
    return original_connection


def apim_policy_uri(context: dict[str, str]) -> str:
    return (
        "https://management.azure.com/subscriptions/"
        f"{context['subscriptionId']}/resourceGroups/{context['resourceGroup']}"
        "/providers/Microsoft.ApiManagement/service/"
        f"{context['apimName']}/apis/sherpa-mcp/policies/policy"
        f"?api-version={API_VERSION_APIM}"
    )


def configure_apim_project_identity(
    context: dict[str, str], existing_state: dict[str, Any]
) -> tuple[str, str, str]:
    project = az_json(
        [
            "rest",
            "--method",
            "get",
            "--uri",
            f"https://management.azure.com{context['projectId']}"
            f"?api-version={API_VERSION_PROJECT}",
        ]
    )
    principal_id = project.get("identity", {}).get("principalId")
    if not principal_id:
        raise RuntimeError("The Foundry project does not have a managed identity.")
    project_identity_client_id = az_tsv(
        ["ad", "sp", "show", "--id", principal_id, "--query", "appId"]
    )

    current_policy = run(
        [
            "az",
            "rest",
            "--method",
            "get",
            "--uri",
            apim_policy_uri(context),
            "--output",
            "tsv",
        ]
    ).lstrip("\ufeff")
    original_policy = existing_state.get("originalApimPolicy", current_policy)

    policy = original_policy.replace(
        "<validate-azure-ad-token ",
        '<validate-azure-ad-token output-token-variable-name="validatedToken" ',
        1,
    )
    required_start = policy.find("<required-claims>")
    required_end = policy.find("</required-claims>")
    if required_start == -1 or required_end == -1:
        raise RuntimeError("The Sherpa APIM policy does not contain required claims.")
    required_end += len("</required-claims>")
    policy = policy[:required_start] + policy[required_end:]

    validate_end = policy.find("</validate-azure-ad-token>")
    if validate_end == -1:
        raise RuntimeError("The Sherpa APIM policy is missing token validation.")
    validate_end += len("</validate-azure-ad-token>")
    authorization = f"""
    <choose>
      <when condition='@{{
        var jwt = (Jwt)context.Variables["validatedToken"];
        var delegated = jwt.Claims.ContainsKey("scp")
          &amp;&amp; jwt.Claims["scp"].Any(value => value.Split(" ".ToCharArray()).Contains("user_impersonate"));
        var clientId = jwt.Claims.ContainsKey("azp")
          ? jwt.Claims["azp"].FirstOrDefault()
          : (jwt.Claims.ContainsKey("appid") ? jwt.Claims["appid"].FirstOrDefault() : "");
        var objectId = jwt.Claims.ContainsKey("oid") ? jwt.Claims["oid"].FirstOrDefault() : "";
        return !(delegated
          || clientId == "{project_identity_client_id}"
          || objectId == "{principal_id}");
      }}'>
        <return-response>
          <set-status code="403" reason="Forbidden" />
          <set-body>{{"error":"forbidden","message":"The caller is not authorized for Sherpa MCP."}}</set-body>
        </return-response>
      </when>
    </choose>"""
    policy = policy[:validate_end] + authorization + policy[validate_end:]
    put_arm_resource(
        apim_policy_uri(context),
        {"properties": {"format": "rawxml", "value": policy}},
    )
    return original_policy, project_identity_client_id, principal_id


def project_client(context: dict[str, str]) -> AIProjectClient:
    credential = AzureCliCredential(tenant_id=context["tenantId"])
    return AIProjectClient(
        endpoint=context["projectEndpoint"],
        credential=credential,
    )


def create_agent(context: dict[str, str]) -> str:
    client = project_client(context)
    try:
        client.agents.get(AGENT_NAME)
        client.agents.delete(AGENT_NAME, force=True)
    except ResourceNotFoundError:
        pass

    tool = MCPTool(
        server_label="sherpa",
        server_url=context["sherpaUrl"],
        require_approval="always",
        project_connection_id=CONNECTION_NAME,
    )
    agent = client.agents.create_version(
        agent_name=AGENT_NAME,
        definition=PromptAgentDefinition(
            model=MODEL_DEPLOYMENT_NAME,
            instructions=(
                "You are Sherpa Agent, a hiking assistant. Use the Sherpa MCP "
                "tools for trail planning, weather, trail conditions, and gear "
                "recommendations. Base recommendations on tool results, explain "
                "safety considerations, and never invent tool output."
            ),
            tools=[tool],
        ),
        description=(
            "Sherpa Agent - hiking assistant powered by the catalog-registered "
            "Sherpa MCP Server"
        ),
        metadata={"displayName": AGENT_DISPLAY_NAME, "sampleOwner": SAMPLE_OWNER},
    )
    return agent.version


def setup() -> None:
    context = get_context()
    existing_state = (
        json.loads(STATE_FILE.read_text(encoding="utf-8"))
        if STATE_FILE.exists()
        else {}
    )
    ensure_foundry_role(context)
    original_connection = configure_catalog_connection(context)
    (
        original_policy,
        project_identity_client_id,
        project_identity_principal_id,
    ) = configure_apim_project_identity(context, existing_state)
    version = create_agent(context)

    state = {
        **context,
        "agentName": AGENT_NAME,
        "agentDisplayName": AGENT_DISPLAY_NAME,
        "agentVersion": version,
        "connectionName": CONNECTION_NAME,
        "projectIdentityClientId": project_identity_client_id,
        "projectIdentityPrincipalId": project_identity_principal_id,
        "originalConnection": original_connection,
        "originalApimPolicy": original_policy,
    }
    STATE_FILE.write_text(json.dumps(state, indent=2) + "\n", encoding="utf-8")
    STATE_FILE.chmod(0o600)

    print("Sherpa Agent is ready.")
    print(f"  Foundry project: {context['projectEndpoint']}")
    print(f"  Agent resource name: {AGENT_NAME}")
    print(f"  Display name: {AGENT_DISPLAY_NAME}")
    print(f"  Model: {MODEL_DEPLOYMENT_NAME}")
    print(f"  Catalog connection: {CONNECTION_NAME}")
    print(f"  Sherpa MCP: {context['sherpaUrl']}")
    print(f"  Authentication: Foundry project managed identity")
    print("  MCP approval: required for every call")


def load_state() -> dict[str, Any]:
    if not STATE_FILE.exists():
        raise RuntimeError("Run the setup script before testing or cleanup.")
    return json.loads(STATE_FILE.read_text(encoding="utf-8"))


def response_items(response: Any, item_type: str) -> list[Any]:
    return [item for item in response.output if item.type == item_type]


def test_agent() -> None:
    state = load_state()
    client = project_client(state)
    openai = client.get_openai_client()
    prompt = (
        "Plan a safe day hike at Mount Rainier. Use Sherpa tools to check the "
        "weather, trail conditions, and recommended gear."
    )
    response = openai.responses.create(
        input=prompt,
        extra_body={
            "agent_reference": {"name": AGENT_NAME, "type": "agent_reference"},
            "tool_choice": "required",
        },
    )
    approved_calls = 0

    for _ in range(12):
        consent_requests = response_items(response, "oauth_consent_request")
        if consent_requests:
            raise RuntimeError(
                "Foundry requested OAuth consent instead of project managed identity."
            )

        approval_requests = response_items(response, "mcp_approval_request")
        if approval_requests:
            approvals: ResponseInputParam = []
            for item in approval_requests:
                print("\nMCP approval requested:")
                print(f"  Server: {item.server_label}")
                print(f"  Tool: {getattr(item, 'name', '<unknown>')}")
                print(
                    "  Arguments: "
                    + json.dumps(
                        getattr(item, "arguments", None), indent=2, default=str
                    )
                )
                approved = input("Approve this call? (y/N): ").strip().lower() == "y"
                approvals.append(
                    McpApprovalResponse(
                        type="mcp_approval_response",
                        approve=approved,
                        approval_request_id=item.id,
                    )
                )
                approved_calls += int(approved)
            response = openai.responses.create(
                input=approvals,
                previous_response_id=response.id,
                extra_body={
                    "agent_reference": {
                        "name": AGENT_NAME,
                        "type": "agent_reference",
                    }
                },
            )
            continue

        if response.output_text:
            print("\nSherpa Agent response:\n")
            print(response.output_text)
            if approved_calls < 1:
                raise RuntimeError("The response completed without an approved MCP call.")
            print(f"\nValidated {approved_calls} approved Sherpa MCP call(s).")
            return

        errors = [
            getattr(item, "error", None)
            for item in response.output
            if getattr(item, "error", None)
        ]
        if errors:
            raise RuntimeError(f"Foundry MCP call failed: {errors}")

    raise RuntimeError("The agent did not complete after consent and approvals.")


def cleanup() -> None:
    state = load_state()
    client = project_client(state)
    try:
        client.agents.delete(state["agentName"], force=True)
        print(f"Deleted agent: {state['agentName']}")
    except ResourceNotFoundError:
        print(f"Agent already absent: {state['agentName']}")

    uri = connection_uri(state)
    original = state.get("originalConnection", {})
    if original.get("existed"):
        put_arm_resource(uri, {"properties": original["properties"]})
        print(f"Restored catalog connection: {state['connectionName']}")
    else:
        run(
            ["az", "rest", "--method", "delete", "--uri", uri, "--output", "none"],
            check=False,
        )
        print(f"Deleted sample connection: {state['connectionName']}")

    put_arm_resource(
        apim_policy_uri(state),
        {
            "properties": {
                "format": "rawxml",
                "value": state["originalApimPolicy"],
            }
        },
    )
    print("Restored the Sherpa APIM authorization policy.")

    STATE_FILE.unlink(missing_ok=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)
    subparsers.add_parser("setup")
    subparsers.add_parser("test")
    subparsers.add_parser("cleanup")
    args = parser.parse_args()

    try:
        if args.command == "setup":
            setup()
        elif args.command == "test":
            test_agent()
        else:
            cleanup()
    except (HttpResponseError, RuntimeError) as error:
        print(f"Error: {error}", file=sys.stderr)
        raise SystemExit(1) from error


if __name__ == "__main__":
    main()
