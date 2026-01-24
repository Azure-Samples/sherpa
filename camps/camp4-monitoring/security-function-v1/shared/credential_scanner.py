"""
Credential Scanner Module

Hybrid approach combining:
1. Regex patterns for known credential formats (API keys, JWTs, etc.)
2. Entropy analysis for unknown high-entropy secrets

Scans text for common credential patterns to prevent accidental exposure
of API keys, passwords, JWTs, and other secrets in MCP responses.
"""

import math
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

# Entropy detection thresholds
ENTROPY_THRESHOLD = 4.5  # Shannon entropy threshold for secrets
MIN_SECRET_LENGTH = 20   # Minimum length to consider for entropy analysis
MAX_SECRET_LENGTH = 200  # Maximum length to consider (avoid analyzing large blobs)


def calculate_entropy(text: str) -> float:
    """
    Calculate Shannon entropy of a string.
    
    High entropy (>4.5) indicates randomness, which is characteristic of:
    - API keys
    - Cryptographic tokens
    - Generated passwords
    - Base64-encoded secrets
    
    Args:
        text: The string to analyze
        
    Returns:
        Shannon entropy value (0-8 for ASCII, higher = more random)
    """
    if not text:
        return 0.0
    
    # Calculate character frequency
    freq = {}
    for char in text:
        freq[char] = freq.get(char, 0) + 1
    
    # Calculate entropy
    length = len(text)
    entropy = 0.0
    for count in freq.values():
        probability = count / length
        entropy -= probability * math.log2(probability)
    
    return entropy


def find_high_entropy_strings(text: str) -> list[tuple[int, int, str, float]]:
    """
    Find high-entropy strings that might be secrets.
    
    Looks for alphanumeric strings that have high entropy,
    which is characteristic of randomly generated secrets.
    
    Args:
        text: The text to scan
        
    Returns:
        List of (start, end, matched_string, entropy) tuples
    """
    # Pattern to find potential secret strings (alphanumeric with common secret chars)
    # Excludes common words by requiring mixed case or numbers
    potential_secrets = re.finditer(
        r'\b[a-zA-Z0-9+/=_-]{' + str(MIN_SECRET_LENGTH) + r',' + str(MAX_SECRET_LENGTH) + r'}\b',
        text
    )
    
    high_entropy_matches = []
    for match in potential_secrets:
        candidate = match.group()
        entropy = calculate_entropy(candidate)
        
        # High entropy + reasonable length = likely a secret
        if entropy >= ENTROPY_THRESHOLD:
            # Additional heuristics to reduce false positives:
            # - Must have at least some digits or mixed case
            has_digits = any(c.isdigit() for c in candidate)
            has_upper = any(c.isupper() for c in candidate)
            has_lower = any(c.islower() for c in candidate)
            
            if has_digits or (has_upper and has_lower):
                high_entropy_matches.append((
                    match.start(),
                    match.end(),
                    candidate,
                    entropy
                ))
    
    return high_entropy_matches


def scan_and_redact(text: str) -> CredentialResult:
    """
    Scan text for credential patterns and high-entropy secrets, then redact them.
    
    Hybrid approach:
    1. First, apply regex patterns for known credential formats
    2. Then, use entropy analysis to catch unknown secret types
    
    Args:
        text: The text to scan for credentials
        
    Returns:
        CredentialResult with redacted text and list of credentials found
    """
    if not text:
        return CredentialResult(redacted_text=text, credentials_found=[])
    
    redacted = text
    credentials_found = []
    
    # Phase 1: Regex-based pattern matching for known credential types
    for pattern, cred_type, replacement in CREDENTIAL_PATTERNS:
        try:
            matches = list(re.finditer(pattern, redacted, re.MULTILINE))
            for match in matches:
                credentials_found.append({
                    "type": cred_type,
                    "pattern": pattern[:50] + "..." if len(pattern) > 50 else pattern,
                    "position": match.start(),
                    "detection": "regex"
                })
            
            redacted = re.sub(pattern, replacement, redacted, flags=re.MULTILINE)
        except re.error:
            # Skip invalid patterns
            continue
    
    # Phase 2: Entropy-based detection for unknown secrets
    # Run on the already-redacted text to avoid double-detection
    high_entropy_secrets = find_high_entropy_strings(redacted)
    
    # Sort by position descending so we can replace without offset issues
    high_entropy_secrets.sort(key=lambda x: x[0], reverse=True)
    
    for start, end, secret, entropy in high_entropy_secrets:
        # Skip if this looks like it was already redacted
        if "[REDACTED" in secret:
            continue
            
        credentials_found.append({
            "type": "HIGH_ENTROPY_SECRET",
            "entropy": round(entropy, 2),
            "position": start,
            "length": len(secret),
            "detection": "entropy"
        })
        
        # Redact the high-entropy string
        redacted = redacted[:start] + "[REDACTED-HIGH_ENTROPY]" + redacted[end:]
    
    return CredentialResult(
        redacted_text=redacted,
        credentials_found=credentials_found
    )
