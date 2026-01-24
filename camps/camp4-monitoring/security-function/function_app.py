"""
Security Function App for Camp 4: Monitoring & Telemetry

Provides two HTTP endpoints for APIM to call:
- /api/input-check: Validates incoming MCP requests for injection patterns
- /api/sanitize-output: Redacts PII and credentials from MCP responses

This version includes structured logging with Azure Monitor integration for
comprehensive security observability - dashboards, KQL queries, and alerting.
"""

import json
import logging
import traceback
import azure.functions as func

from shared.injection_patterns import check_mcp_request_async, extract_texts_from_mcp_request
from shared.pii_detector import detect_and_redact_pii
from shared.credential_scanner import scan_and_redact
from shared.security_logger import (
    configure_telemetry,
    generate_correlation_id,
    log_injection_blocked,
    log_pii_redacted,
    log_credential_detected,
    log_input_check_passed,
    log_security_error,
)

# Configure Azure Monitor telemetry on startup
configure_telemetry()

# Configure logging
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
    correlation_id = req.headers.get("x-correlation-id", generate_correlation_id())

    try:
        # Parse request body
        try:
            body = req.get_json()
        except ValueError:
            log_security_error(
                error_message="Invalid JSON body",
                correlation_id=correlation_id,
                error_type="parse_error"
            )
            return func.HttpResponse(
                json.dumps({"allowed": False, "reason": "Invalid JSON body", "category": "parse_error"}),
                status_code=400,
                mimetype="application/json"
            )

        if not body:
            log_input_check_passed(correlation_id=correlation_id)
            return func.HttpResponse(
                json.dumps({"allowed": True}),
                status_code=200,
                mimetype="application/json"
            )

        tool_name = get_tool_name(body)

        # Hybrid check: regex + Prompt Shields
        result = await check_mcp_request_async(body)

        if not result.is_safe:
            log_injection_blocked(
                injection_type=result.category,
                reason=result.reason,
                correlation_id=correlation_id,
                tool_name=tool_name
            )
            return func.HttpResponse(
                json.dumps({
                    "allowed": False,
                    "reason": result.reason,
                    "category": result.category
                }),
                status_code=200,
                mimetype="application/json"
            )

        log_input_check_passed(correlation_id=correlation_id, tool_name=tool_name)
        return func.HttpResponse(
            json.dumps({"allowed": True}),
            status_code=200,
            mimetype="application/json"
        )

    except Exception as e:
        log_security_error(
            error_message=str(e),
            correlation_id=correlation_id,
            error_type="exception",
            stack_trace=traceback.format_exc()
        )
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
    correlation_id = req.headers.get("x-correlation-id", generate_correlation_id())

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
            entity_types = list(set(e.get("category", "Unknown") for e in pii_result.entities_found))
            log_pii_redacted(
                entity_count=len(pii_result.entities_found),
                entity_types=entity_types,
                correlation_id=correlation_id
            )

        if pii_result.error:
            log_security_error(
                error_message=f"PII detection warning: {pii_result.error}",
                correlation_id=correlation_id,
                error_type="pii_service_error"
            )

        # Step 2: Scan and redact credentials
        cred_result = scan_and_redact(sanitized_text)
        sanitized_text = cred_result.redacted_text

        if cred_result.credentials_found:
            credential_types = list(set(c.get("type", "Unknown") for c in cred_result.credentials_found))
            log_credential_detected(
                credential_count=len(cred_result.credentials_found),
                credential_types=credential_types,
                correlation_id=correlation_id
            )

        return func.HttpResponse(
            sanitized_text,
            status_code=200,
            mimetype="application/json"
        )

    except Exception as e:
        log_security_error(
            error_message=str(e),
            correlation_id=correlation_id,
            error_type="exception",
            stack_trace=traceback.format_exc()
        )
        # Fail open for availability - return original body
        # In production, consider failing closed
        return func.HttpResponse(
            req.get_body().decode('utf-8', errors='replace'),
            status_code=200,
            mimetype="application/json"
        )


@app.route(route="health", methods=["GET"])
def health(req: func.HttpRequest) -> func.HttpResponse:
    """Health check endpoint."""
    return func.HttpResponse(
        json.dumps({"status": "healthy", "service": "security-function", "version": "2.0-telemetry"}),
        status_code=200,
        mimetype="application/json"
    )
