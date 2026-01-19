"""
Security Function App for Camp 3: I/O Security

Provides two HTTP endpoints for APIM to call:
- /api/input-check: Validates incoming MCP requests for injection patterns
- /api/sanitize-output: Redacts PII and credentials from MCP responses
"""

import asyncio
import json
import logging
import azure.functions as func

from shared.injection_patterns import check_mcp_request, check_mcp_request_async
from shared.pii_detector import detect_and_redact_pii
from shared.credential_scanner import scan_and_redact

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = func.FunctionApp(http_auth_level=func.AuthLevel.ANONYMOUS)


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
    logger.info("input_check invoked")
    
    try:
        # Parse request body
        try:
            body = req.get_json()
        except ValueError:
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
            logger.warning(f"Injection detected: {result.category} - {result.reason}")
            return func.HttpResponse(
                json.dumps({
                    "allowed": False,
                    "reason": result.reason,
                    "category": result.category
                }),
                status_code=200,
                mimetype="application/json"
            )
        
        logger.info("Input check passed")
        return func.HttpResponse(
            json.dumps({"allowed": True}),
            status_code=200,
            mimetype="application/json"
        )
        
    except Exception as e:
        logger.exception("Input check failed with exception")
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
    logger.info("sanitize_output invoked")
    
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
            logger.info(f"Redacted {len(pii_result.entities_found)} PII entities")
        
        if pii_result.error:
            logger.warning(f"PII detection warning: {pii_result.error}")
        
        # Step 2: Scan and redact credentials
        cred_result = scan_and_redact(sanitized_text)
        sanitized_text = cred_result.redacted_text
        
        if cred_result.credentials_found:
            logger.info(f"Redacted {len(cred_result.credentials_found)} credential patterns")
        
        return func.HttpResponse(
            sanitized_text,
            status_code=200,
            mimetype="application/json"
        )
        
    except Exception as e:
        logger.exception("Output sanitization failed with exception")
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
        json.dumps({"status": "healthy", "service": "security-function"}),
        status_code=200,
        mimetype="application/json"
    )
