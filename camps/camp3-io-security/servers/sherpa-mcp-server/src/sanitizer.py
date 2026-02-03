"""Output Sanitizer Module

Calls the Azure Function sanitize-output endpoint to redact PII from responses.
The Function App uses anonymous authentication, so no managed identity is needed.

Sanitization is controlled by the SANITIZE_ENABLED environment variable:
- SANITIZE_ENABLED=false (default): Returns original text, no sanitization
- SANITIZE_ENABLED=true: Calls Azure Function to redact PII

This allows the workshop to demonstrate the vulnerability first, then enable the fix.
"""

import os
import logging
import httpx

logger = logging.getLogger(__name__)

# Configuration from environment variables
# SANITIZE_ENABLED controls whether sanitization is active (default: false for workshop flow)
# SANITIZE_FUNCTION_URL is the full URL: https://func-xxx.azurewebsites.net/api/sanitize-output
SANITIZE_ENABLED = os.environ.get("SANITIZE_ENABLED", "false").lower() == "true"
SANITIZE_FUNCTION_URL = os.environ.get("SANITIZE_FUNCTION_URL", "")


async def sanitize_output(text: str) -> str:
    """
    Sanitize PII from text by calling the Azure Function.
    
    Sanitization only occurs when SANITIZE_ENABLED=true AND SANITIZE_FUNCTION_URL is set.
    This allows the workshop to demonstrate PII leakage before enabling the fix.
    
    Args:
        text: The text to sanitize (typically JSON string)
    
    Returns:
        Sanitized text with PII redacted, or original text if:
        - SANITIZE_ENABLED is false (workshop default)
        - SANITIZE_FUNCTION_URL is not configured
        - Sanitization fails (fail-open strategy)
    """
    # Check if sanitization is enabled (workshop toggle)
    if not SANITIZE_ENABLED:
        logger.debug("SANITIZE_ENABLED=false, skipping sanitization (workshop mode)")
        return text
    
    # Check if function URL is configured
    if not SANITIZE_FUNCTION_URL:
        logger.warning("SANITIZE_ENABLED=true but SANITIZE_FUNCTION_URL not set")
        return text
    
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.post(
                SANITIZE_FUNCTION_URL,
                content=text,
                headers={"Content-Type": "application/json"}
            )
            
            if response.status_code == 200:
                logger.debug("Sanitization successful")
                return response.text
            else:
                logger.warning(f"Sanitization failed with status {response.status_code}, returning original")
                return text
                
    except httpx.TimeoutException:
        logger.warning("Sanitization timed out, returning original (fail open)")
        return text
    except Exception as e:
        logger.warning(f"Sanitization error: {e}, returning original (fail open)")
        return text
