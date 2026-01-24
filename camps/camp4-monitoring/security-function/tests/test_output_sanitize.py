"""Tests for output sanitization (credential scanning).

NOTE: All credential values in this file are FAKE test fixtures.
They are intentionally formatted to match real credential patterns
for testing purposes only. No real secrets are stored in this file.
"""

import pytest
import sys
import os

# Add parent directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from shared.credential_scanner import scan_and_redact, calculate_entropy

# Test fixtures - these are FAKE credentials for pattern matching tests
FAKE_API_KEY = "sk_test_FAKE_KEY_FOR_TESTING_1234567890"
FAKE_PASSWORD = "FAKE_TEST_P@ssw0rd_NOT_REAL"
FAKE_JWT = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ0ZXN0IjoiZmFrZSJ9.FAKE_SIG"
FAKE_GITHUB_TOKEN = "ghp_xxxxxxxxxxTESTxxxxxxxxxxxxxxxxxx"
# High entropy string that looks like a random secret (not matching known patterns)
FAKE_HIGH_ENTROPY_SECRET = "aB3dE5fG7hJ9kL1mN3pQ5rS7tU9vW1xY3z"


class TestAPIKeyRedaction:
    """Test API key credential scanning."""
    
    def test_api_key_equals(self):
        """Detect api_key=value pattern."""
        text = f'api_key={FAKE_API_KEY}'
        result = scan_and_redact(text)
        assert "[REDACTED-API_KEY]" in result.redacted_text
        assert len(result.credentials_found) > 0
        
    def test_apikey_colon(self):
        """Detect apikey: value pattern."""
        text = 'apikey: "FAKE_TEST_KEY_1234567890abcd"'
        result = scan_and_redact(text)
        assert "[REDACTED-API_KEY]" in result.redacted_text


class TestPasswordRedaction:
    """Test password credential scanning."""
    
    def test_password_equals(self):
        """Detect password=value pattern."""
        text = f'password={FAKE_PASSWORD}'
        result = scan_and_redact(text)
        assert "[REDACTED-PASSWORD]" in result.redacted_text
        
    def test_pwd_colon(self):
        """Detect pwd: value pattern."""
        text = 'pwd: "FAKE_hunter2_TEST"'
        result = scan_and_redact(text)
        assert "[REDACTED-PASSWORD]" in result.redacted_text


class TestJWTRedaction:
    """Test JWT credential scanning."""
    
    def test_bearer_token(self):
        """Detect Bearer JWT pattern."""
        text = f'Authorization: Bearer {FAKE_JWT}'
        result = scan_and_redact(text)
        assert "[REDACTED-JWT]" in result.redacted_text
        
    def test_standalone_jwt(self):
        """Detect standalone JWT pattern."""
        text = f'token: {FAKE_JWT}'
        result = scan_and_redact(text)
        assert "[REDACTED" in result.redacted_text


class TestGitHubTokenRedaction:
    """Test GitHub token scanning."""
    
    def test_github_pat(self):
        """Detect GitHub personal access token."""
        # Note: 'token:' prefix matches generic SECRET pattern before GitHub-specific pattern
        text = f'token: {FAKE_GITHUB_TOKEN}'
        result = scan_and_redact(text)
        # May be redacted as SECRET (generic) or GITHUB_TOKEN (specific)
        assert "[REDACTED" in result.redacted_text
        assert FAKE_GITHUB_TOKEN not in result.redacted_text


class TestPrivateKeyRedaction:
    """Test private key scanning."""
    
    def test_rsa_private_key(self):
        """Detect RSA private key."""
        # This is a FAKE key structure, not a real key
        text = '''-----BEGIN RSA PRIVATE KEY-----
FAKEFAKEFAKEFAKEFAKEFAKEFAKEFAKEFAKEFAKEFAKEFAKEFAKEFAKEFAKE
-----END RSA PRIVATE KEY-----'''
        result = scan_and_redact(text)
        assert "[REDACTED-PRIVATE_KEY]" in result.redacted_text


class TestEntropyDetection:
    """Test entropy-based secret detection."""
    
    def test_calculate_entropy_low(self):
        """Low entropy for repetitive strings."""
        entropy = calculate_entropy("aaaaaaaaaa")
        assert entropy < 1.0  # Very low entropy
        
    def test_calculate_entropy_high(self):
        """High entropy for random-looking strings."""
        entropy = calculate_entropy(FAKE_HIGH_ENTROPY_SECRET)
        assert entropy > 4.0  # High entropy
        
    def test_high_entropy_secret_detected(self):
        """Detect high-entropy string that doesn't match known patterns."""
        # This looks like a random secret but doesn't match API key, password, etc.
        text = f'unknown_credential: {FAKE_HIGH_ENTROPY_SECRET}'
        result = scan_and_redact(text)
        # Should be caught by either regex or entropy
        assert "[REDACTED" in result.redacted_text
        assert FAKE_HIGH_ENTROPY_SECRET not in result.redacted_text
        
    def test_normal_text_not_flagged(self):
        """Normal English text should not trigger entropy detection."""
        text = "The quick brown fox jumps over the lazy dog"
        result = scan_and_redact(text)
        assert result.redacted_text == text
        assert len(result.credentials_found) == 0


class TestSafeText:
    """Test that safe text passes through unchanged."""
    
    def test_normal_json(self):
        """Normal JSON should pass through."""
        text = '{"name": "John Smith", "location": "Denver, CO"}'
        result = scan_and_redact(text)
        assert result.redacted_text == text
        assert len(result.credentials_found) == 0
        
    def test_empty_string(self):
        """Empty string should pass through."""
        result = scan_and_redact("")
        assert result.redacted_text == ""
        
    def test_normal_text(self):
        """Normal text without credentials."""
        text = "The weather in Denver is sunny with a high of 75F."
        result = scan_and_redact(text)
        assert result.redacted_text == text


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
