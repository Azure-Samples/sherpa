"""
Security Function App for Camp 4: Monitoring & Telemetry
Version 1.0 - Basic Logging

Provides two HTTP endpoints for APIM to call:
- /api/input-check: Validates incoming MCP requests for injection patterns
- /api/sanitize-output: Redacts PII and credentials from MCP responses

This version uses basic Python logging - the type of logging that makes
security incidents invisible when you need them most. It works, but you
can't query it, alert on it, or trace requests across services.

PROBLEM: When something goes wrong at 3 AM, you'll grep through text logs
hoping to find what you need. Good luck with that.
"""

import json
import logging
import traceback
import azure.functions as func

from shared.injection_patterns import check_mcp_request_async, extract_texts_from_mcp_request
from shared.pii_detector import detect_and_redact_pii
from shared.credential_scanner import scan_and_redact

# Basic logging - works but invisible to Azure Monitor
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = func.FunctionApp(http_auth_level=func.AuthLevel.ANONYMOUS)


def get_tool_name(body: dict) -> str | None:
    """Extract MCP tool name from request body if present."""
    return body.get("params", {}).get("name")


@app.route(route="input-check", methods=["POST"])
async def input_check(req: func.HttpRequest) -> func.HttpResponse:
    """
    Check incoming MCP request for injection patterns.

    Hybrid approach:
    1. Fast regex check for known patterns (shell, SQL, path traversal)
    2. Azure AI Content Safety Prompt Shields for sophisticated prompt injection

    Returns:
        JSON: {"allowed": true/false, "reason": string, "category": string}
    """
    try:
        # Parse request body
        try:
            body = req.get_json()
        except ValueError:
            # Basic logging: No correlation ID, no structured data
            # Can you find this in a sea of logs? Maybe. Eventually.
            logger.warning("Invalid JSON body received")
            return func.HttpResponse(
                json.dumps({"allowed": False, "reason": "Invalid JSON body", "category": "parse_error"}),
                status_code=400,
                mimetype="application/json"
            )

        if not body:
            return func.HttpResponse(
                json.dumps({"allowed": True}),
                status_code=200,
                mimetype="application/json"
            )

        # Hybrid check: regex + Prompt Shields
        result = await check_mcp_request_async(body)

        if not result.is_safe:
            # This is what basic logging looks like for a security event.
            # No correlation ID. No tool name. No structured fields.
            # Try writing a KQL query to find all SQL injection attempts.
            logger.warning(f"Injection blocked: {result.category}")
            return func.HttpResponse(
                json.dumps({
                    "allowed": False,
                    "reason": result.reason,
                    "category": result.category
                }),
                status_code=200,
                mimetype="application/json"
            )

        return func.HttpResponse(
            json.dumps({"allowed": True}),
            status_code=200,
            mimetype="application/json"
        )

    except Exception as e:
        # Exception with stack trace but no correlation to the request
        # Which user? Which tool? Which session? Who knows!
        logger.error(f"Error in input-check: {str(e)}")
        logger.debug(traceback.format_exc())
        return func.HttpResponse(
            json.dumps({"allowed": False, "reason": f"Internal error: {str(e)}", "category": "error"}),
            status_code=500,
            mimetype="application/json"
        )


@app.route(route="sanitize-output", methods=["POST"])
def sanitize_output(req: func.HttpRequest) -> func.HttpResponse:
    """
    Sanitize MCP response by redacting PII and credentials.

    Performs:
    - PII detection using Azure AI Language (MCP-03)
    - Credential pattern scanning (MCP-03)

    Returns:
        The sanitized response body with sensitive data redacted
    """
    try:
        # Get raw body as text
        body_text = req.get_body().decode('utf-8')

        if not body_text or not body_text.strip():
            return func.HttpResponse(
                body_text,
                status_code=200,
                mimetype="application/json"
            )

        # Step 1: Detect and redact PII using Azure AI Language
        pii_result = detect_and_redact_pii(body_text)
        sanitized_text = pii_result.redacted_text

        if pii_result.entities_found:
            # "Found some PII" - great, but how many? What types?
            # What request was this? Can you alert on patterns?
            logger.warning(f"PII detected and redacted: {len(pii_result.entities_found)} entities")

        if pii_result.error:
            logger.warning(f"PII detection warning: {pii_result.error}")

        # Step 2: Scan and redact credentials
        cred_result = scan_and_redact(sanitized_text)
        sanitized_text = cred_result.redacted_text

        if cred_result.credentials_found:
            # Critical security event logged as a simple string.
            # Hope you never need to investigate a credential leak.
            logger.warning(f"Credentials detected and redacted: {len(cred_result.credentials_found)} found")

        return func.HttpResponse(
            sanitized_text,
            status_code=200,
            mimetype="application/json"
        )

    except Exception as e:
        logger.error(f"Error in sanitize-output: {str(e)}")
        logger.debug(traceback.format_exc())
        # Fail open for availability - return original body
        return func.HttpResponse(
            req.get_body().decode('utf-8', errors='replace'),
            status_code=200,
            mimetype="application/json"
        )


@app.route(route="health", methods=["GET"])
def health(req: func.HttpRequest) -> func.HttpResponse:
    """Health check endpoint."""
    return func.HttpResponse(
        json.dumps({"status": "healthy", "service": "security-function", "version": "1.0-basic"}),
        status_code=200,
        mimetype="application/json"
    )
