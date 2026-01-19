"""
Credential Scanner Module

Scans text for common credential patterns to prevent accidental exposure
of API keys, passwords, JWTs, and other secrets in MCP responses.
"""

import re
from typing import NamedTuple


class CredentialResult(NamedTuple):
    """Result of credential scanning."""
    redacted_text: str
    credentials_found: list[dict]


# Credential patterns with their redaction labels
CREDENTIAL_PATTERNS: list[tuple[str, str, str]] = [
    # API Keys
    (r'(?i)(api[_-]?key|apikey)\s*[=:]\s*["\']?([a-zA-Z0-9_-]{20,})["\']?',
     "API_KEY", r'\1=[REDACTED-API_KEY]'),
    
    # Generic secrets/tokens
    (r'(?i)(secret|token|auth[_-]?token)\s*[=:]\s*["\']?([a-zA-Z0-9_-]{16,})["\']?',
     "SECRET", r'\1=[REDACTED-SECRET]'),
    
    # Passwords
    (r'(?i)(password|passwd|pwd)\s*[=:]\s*["\']?([^\s"\']{8,})["\']?',
     "PASSWORD", r'\1=[REDACTED-PASSWORD]'),
    
    # JWTs (header.payload.signature format)
    (r'(?i)bearer\s+([a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+)',
     "JWT", 'Bearer [REDACTED-JWT]'),
    
    # Generic JWT pattern (not in Authorization header)
    (r'\b(eyJ[a-zA-Z0-9_-]*\.eyJ[a-zA-Z0-9_-]*\.[a-zA-Z0-9_-]*)\b',
     "JWT", '[REDACTED-JWT]'),
    
    # AWS Access Keys
    (r'(?i)(aws[_-]?access[_-]?key[_-]?id)\s*[=:]\s*["\']?(AKIA[A-Z0-9]{16})["\']?',
     "AWS_ACCESS_KEY", r'\1=[REDACTED-AWS_ACCESS_KEY]'),
    
    # AWS Secret Keys
    (r'(?i)(aws[_-]?secret[_-]?access[_-]?key)\s*[=:]\s*["\']?([a-zA-Z0-9/+=]{40})["\']?',
     "AWS_SECRET_KEY", r'\1=[REDACTED-AWS_SECRET_KEY]'),
    
    # Azure Storage Connection Strings
    (r'(?i)(DefaultEndpointsProtocol=https;AccountName=[^;]+;AccountKey=)([a-zA-Z0-9+/=]{88})',
     "AZURE_STORAGE_KEY", r'\1[REDACTED-AZURE_STORAGE_KEY]'),
    
    # Azure Storage Account Keys
    (r'(?i)(AccountKey\s*=\s*)([a-zA-Z0-9+/=]{88})',
     "AZURE_STORAGE_KEY", r'\1[REDACTED-AZURE_STORAGE_KEY]'),
    
    # GitHub Personal Access Tokens
    (r'\b(ghp_[a-zA-Z0-9]{36})\b',
     "GITHUB_TOKEN", '[REDACTED-GITHUB_TOKEN]'),
    
    # GitHub OAuth Tokens
    (r'\b(gho_[a-zA-Z0-9]{36})\b',
     "GITHUB_OAUTH", '[REDACTED-GITHUB_OAUTH]'),
    
    # Slack Tokens
    (r'\b(xox[baprs]-[0-9]+-[a-zA-Z0-9-]+)\b',
     "SLACK_TOKEN", '[REDACTED-SLACK_TOKEN]'),
    
    # Private Keys (PEM format)
    (r'-----BEGIN (RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----[\s\S]*?-----END (RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----',
     "PRIVATE_KEY", '[REDACTED-PRIVATE_KEY]'),
    
    # Generic high-entropy strings that look like secrets (base64-ish, 32+ chars)
    # This is a catch-all for unknown credential types
    (r'(?i)(key|secret|credential|token|auth)\s*[=:]\s*["\']?([a-zA-Z0-9+/=_-]{32,})["\']?',
     "GENERIC_SECRET", r'\1=[REDACTED-SECRET]'),
]


def scan_and_redact(text: str) -> CredentialResult:
    """
    Scan text for credential patterns and redact them.
    
    Args:
        text: The text to scan for credentials
        
    Returns:
        CredentialResult with redacted text and list of credentials found
    """
    if not text:
        return CredentialResult(redacted_text=text, credentials_found=[])
    
    redacted = text
    credentials_found = []
    
    for pattern, cred_type, replacement in CREDENTIAL_PATTERNS:
        try:
            matches = list(re.finditer(pattern, redacted, re.MULTILINE))
            for match in matches:
                credentials_found.append({
                    "type": cred_type,
                    "pattern": pattern[:50] + "..." if len(pattern) > 50 else pattern,
                    "position": match.start()
                })
            
            redacted = re.sub(pattern, replacement, redacted, flags=re.MULTILINE)
        except re.error:
            # Skip invalid patterns
            continue
    
    return CredentialResult(
        redacted_text=redacted,
        credentials_found=credentials_found
    )
