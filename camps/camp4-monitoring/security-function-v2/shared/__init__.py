"""Shared modules for security function v2 with structured logging."""
from .injection_patterns import check_mcp_request_async, extract_texts_from_mcp_request, check_patterns
from .pii_detector import detect_and_redact_pii
from .credential_scanner import scan_and_redact
from .security_logger import (
    configure_telemetry,
    generate_correlation_id,
    log_injection_blocked,
    log_pii_redacted,
    log_credential_detected,
    log_input_check_passed,
    log_security_error,
)
