"""Tests for output sanitization (credential scanning)."""

import pytest
import sys
import os

# Add parent directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from shared.credential_scanner import scan_and_redact


class TestAPIKeyRedaction:
    """Test API key credential scanning."""
    
    def test_api_key_equals(self):
        """Detect api_key=value pattern."""
        text = 'api_key=sk_live_abc123def456ghi789jkl012'
        result = scan_and_redact(text)
        assert "[REDACTED-API_KEY]" in result.redacted_text
        assert len(result.credentials_found) > 0
        
    def test_apikey_colon(self):
        """Detect apikey: value pattern."""
        text = 'apikey: "abcdefghij1234567890abcd"'
        result = scan_and_redact(text)
        assert "[REDACTED-API_KEY]" in result.redacted_text


class TestPasswordRedaction:
    """Test password credential scanning."""
    
    def test_password_equals(self):
        """Detect password=value pattern."""
        text = 'password=MySecretP@ssw0rd!'
        result = scan_and_redact(text)
        assert "[REDACTED-PASSWORD]" in result.redacted_text
        
    def test_pwd_colon(self):
        """Detect pwd: value pattern."""
        text = 'pwd: "hunter2secret"'
        result = scan_and_redact(text)
        assert "[REDACTED-PASSWORD]" in result.redacted_text


class TestJWTRedaction:
    """Test JWT credential scanning."""
    
    def test_bearer_token(self):
        """Detect Bearer JWT pattern."""
        text = 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dozjgNryP4J3jVmNHl0w5N_XgL0n3I9PlFUP0THsR8U'
        result = scan_and_redact(text)
        assert "[REDACTED-JWT]" in result.redacted_text
        
    def test_standalone_jwt(self):
        """Detect standalone JWT pattern."""
        text = 'token: eyJhbGciOiJIUzI1NiJ9.eyJ0ZXN0IjoidmFsdWUifQ.signature'
        result = scan_and_redact(text)
        assert "[REDACTED" in result.redacted_text


class TestAWSKeyRedaction:
    """Test AWS credential scanning."""
    
    def test_aws_access_key(self):
        """Detect AWS access key pattern."""
        text = 'aws_access_key_id=AKIAIOSFODNN7EXAMPLE'
        result = scan_and_redact(text)
        assert "[REDACTED-AWS_ACCESS_KEY]" in result.redacted_text


class TestGitHubTokenRedaction:
    """Test GitHub token scanning."""
    
    def test_github_pat(self):
        """Detect GitHub personal access token."""
        text = 'token: ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'
        result = scan_and_redact(text)
        assert "[REDACTED-GITHUB_TOKEN]" in result.redacted_text


class TestPrivateKeyRedaction:
    """Test private key scanning."""
    
    def test_rsa_private_key(self):
        """Detect RSA private key."""
        text = '''-----BEGIN RSA PRIVATE KEY-----
MIIEowIBAAKCAQEA0Z3VS5JJcds3xfn/ygWyf8gS9bUZj7Lj9Xq5l9V8x4Y3X2c1
-----END RSA PRIVATE KEY-----'''
        result = scan_and_redact(text)
        assert "[REDACTED-PRIVATE_KEY]" in result.redacted_text


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
