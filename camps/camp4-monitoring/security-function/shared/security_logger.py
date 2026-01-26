"""
Telemetry Module for Structured Security Logging

Provides structured logging with custom dimensions for Azure Monitor / Log Analytics.
Enables rich KQL queries for security dashboards and alerting.

Event types align with security function operations:
- INJECTION_BLOCKED: Input validation blocked a request
- PII_REDACTED: PII was detected and redacted from output
- CREDENTIAL_DETECTED: Credential patterns found and redacted
- INPUT_CHECK_PASSED: Request passed all security checks
- SECURITY_ERROR: Security function encountered an error
"""

import os
import logging
import uuid
from datetime import datetime
from typing import Any

# Configure Azure Monitor OpenTelemetry if connection string is available
_azure_monitor_configured = False

def configure_telemetry():
    """
    Configure Azure Monitor OpenTelemetry for Application Insights integration.

    Should be called once at function app startup. Falls back to standard
    logging if APPLICATIONINSIGHTS_CONNECTION_STRING is not set.
    """
    global _azure_monitor_configured

    if _azure_monitor_configured:
        return

    connection_string = os.environ.get("APPLICATIONINSIGHTS_CONNECTION_STRING")
    if connection_string:
        try:
            from azure.monitor.opentelemetry import configure_azure_monitor
            configure_azure_monitor(
                connection_string=connection_string,
                logger_name="security-function"
            )
            _azure_monitor_configured = True
            logging.info("Azure Monitor telemetry configured successfully")
        except ImportError:
            logging.warning("azure-monitor-opentelemetry not installed, using standard logging")
        except Exception as e:
            logging.warning(f"Failed to configure Azure Monitor: {e}")
    else:
        logging.info("No Application Insights connection string, using standard logging")

# Get logger after potential Azure Monitor configuration
logger = logging.getLogger("security-function")


class SecurityEventType:
    """Constants for security event types used in structured logging."""
    INJECTION_BLOCKED = "INJECTION_BLOCKED"
    PII_REDACTED = "PII_REDACTED"
    CREDENTIAL_DETECTED = "CREDENTIAL_DETECTED"
    INPUT_CHECK_PASSED = "INPUT_CHECK_PASSED"
    SECURITY_ERROR = "SECURITY_ERROR"


def generate_correlation_id() -> str:
    """Generate a unique correlation ID for request tracing."""
    return str(uuid.uuid4())


def log_security_event(
    event_type: str,
    category: str,
    message: str,
    correlation_id: str,
    severity: str = "INFO",
    extra_dimensions: dict[str, Any] | None = None
) -> None:
    """
    Log a structured security event with custom dimensions.

    Custom dimensions enable rich KQL queries like:
        AppTraces
        | where Properties.event_type == "INJECTION_BLOCKED"
        | summarize count() by tostring(Properties.category)

    Args:
        event_type: One of SecurityEventType constants
        category: Specific category (e.g., "shell_injection", "prompt_injection")
        message: Human-readable log message
        correlation_id: Request correlation ID for tracing
        severity: Log severity (INFO, WARNING, ERROR, CRITICAL)
        extra_dimensions: Additional key-value pairs for the log
    """
    custom_dimensions = {
        "event_type": event_type,
        "category": category,
        "correlation_id": correlation_id,
        "severity": severity,
        "timestamp_utc": datetime.utcnow().isoformat(),
        "service": "security-function",
    }

    if extra_dimensions:
        custom_dimensions.update(extra_dimensions)

    # Log with custom_dimensions in extra dict for Azure Monitor
    log_level = getattr(logging, severity.upper(), logging.INFO)
    logger.log(log_level, message, extra={"custom_dimensions": custom_dimensions})


def log_injection_blocked(
    injection_type: str,
    reason: str,
    correlation_id: str,
    tool_name: str | None = None
) -> None:
    """
    Log when an injection attack is blocked.

    Args:
        injection_type: Type of injection (shell_injection, sql_injection, prompt_injection, path_traversal)
        reason: Human-readable reason for blocking
        correlation_id: Request correlation ID
        tool_name: MCP tool name if available
    """
    extra = {"injection_type": injection_type}
    if tool_name:
        extra["tool_name"] = tool_name

    log_security_event(
        event_type=SecurityEventType.INJECTION_BLOCKED,
        category=injection_type,
        message=f"Injection blocked: {reason}",
        correlation_id=correlation_id,
        severity="WARNING",
        extra_dimensions=extra
    )


def log_pii_redacted(
    entity_count: int,
    entity_types: list[str],
    correlation_id: str
) -> None:
    """
    Log when PII is detected and redacted.

    Args:
        entity_count: Number of PII entities found
        entity_types: List of PII categories (e.g., ["Email", "PhoneNumber"])
        correlation_id: Request correlation ID
    """
    log_security_event(
        event_type=SecurityEventType.PII_REDACTED,
        category="pii_redaction",
        message=f"PII redacted: {entity_count} entities of types {entity_types}",
        correlation_id=correlation_id,
        severity="INFO",
        extra_dimensions={
            "entity_count": entity_count,
            "entity_types": ",".join(entity_types) if entity_types else ""
        }
    )


def log_credential_detected(
    credential_count: int,
    credential_types: list[str],
    correlation_id: str
) -> None:
    """
    Log when credentials are detected and redacted.

    Args:
        credential_count: Number of credentials found
        credential_types: List of credential types (e.g., ["API_KEY", "JWT"])
        correlation_id: Request correlation ID
    """
    log_security_event(
        event_type=SecurityEventType.CREDENTIAL_DETECTED,
        category="credential_exposure",
        message=f"Credentials redacted: {credential_count} items of types {credential_types}",
        correlation_id=correlation_id,
        severity="WARNING",
        extra_dimensions={
            "credential_count": credential_count,
            "credential_types": ",".join(credential_types) if credential_types else ""
        }
    )


def log_input_check_passed(
    correlation_id: str,
    tool_name: str | None = None
) -> None:
    """
    Log when an input check passes all security validations.

    Args:
        correlation_id: Request correlation ID
        tool_name: MCP tool name if available
    """
    extra = {}
    if tool_name:
        extra["tool_name"] = tool_name

    log_security_event(
        event_type=SecurityEventType.INPUT_CHECK_PASSED,
        category="input_validation",
        message="Input check passed all security validations",
        correlation_id=correlation_id,
        severity="INFO",
        extra_dimensions=extra
    )


def log_security_error(
    error_message: str,
    correlation_id: str,
    error_type: str = "unknown",
    stack_trace: str | None = None
) -> None:
    """
    Log when a security function encounters an error.

    Args:
        error_message: Error description
        correlation_id: Request correlation ID
        error_type: Type of error (e.g., "parse_error", "service_unavailable")
        stack_trace: Optional stack trace for debugging
    """
    extra = {"error_type": error_type}
    if stack_trace:
        extra["stack_trace"] = stack_trace[:1000]  # Truncate long traces

    log_security_event(
        event_type=SecurityEventType.SECURITY_ERROR,
        category="error",
        message=f"Security function error: {error_message}",
        correlation_id=correlation_id,
        severity="ERROR",
        extra_dimensions=extra
    )
