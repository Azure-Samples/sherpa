"""
Injection Pattern Detection Module

Hybrid approach combining:
1. Fast regex-based detection for known patterns (instant, free)
2. Azure AI Content Safety Prompt Shields for sophisticated attacks (AI-powered)

Organized by OWASP MCP risk category for clear documentation and maintenance.
"""

import os
import re
import logging
from typing import NamedTuple

import aiohttp
from azure.identity.aio import DefaultAzureCredential

logger = logging.getLogger(__name__)


class DetectionResult(NamedTuple):
    """Result of pattern detection."""
    is_safe: bool
    category: str
    reason: str


# Organized by OWASP MCP risk category
INJECTION_PATTERNS: dict[str, list[tuple[str, str]]] = {
    # MCP-05: Command Injection - Shell/OS command execution
    "shell_injection": [
        (r"[;&|`]",
         "Shell metacharacter detected"),
        (r"\$\([^)]+\)",
         "Command substitution pattern detected"),
        (r"`[^`]+`",
         "Backtick command execution detected"),
        (r"\|\s*(cat|ls|rm|curl|wget|bash|sh|python|perl|ruby|nc|netcat)",
         "Pipe to dangerous command detected"),
        (r">\s*/",
         "File redirect to root path detected"),
        (r"&&\s*(rm|del|format|mkfs)",
         "Destructive command chain detected"),
        (r"\$\{[^}]+\}",
         "Shell variable expansion detected"),
        (r"\\x[0-9a-fA-F]{2}",
         "Hex-encoded shell character detected"),
    ],
    
    # MCP-05: SQL Injection - Database query manipulation
    "sql_injection": [
        (r"'\s*(OR|AND)\s+['\d]",
         "SQL boolean injection detected"),
        (r";\s*(DROP|DELETE|UPDATE|INSERT|TRUNCATE|ALTER)",
         "SQL statement terminator with DDL/DML detected"),
        (r"UNION\s+(ALL\s+)?SELECT",
         "UNION-based SQL injection detected"),
        (r"--\s*$",
         "SQL comment terminator detected"),
        (r"'\s*;\s*--",
         "Quote escape with comment detected"),
        (r"1\s*=\s*1",
         "Tautology injection detected"),
        (r"EXEC\s*\(",
         "Stored procedure execution detected"),
        (r"xp_\w+",
         "SQL Server extended procedure detected"),
        (r"INTO\s+(OUT|DUMP)FILE",
         "SQL file write attempt detected"),
    ],
    
    # MCP-05: Path Traversal - File system access
    "path_traversal": [
        (r"\.\./",
         "Directory traversal (../) detected"),
        (r"\.\.\\",
         r"Directory traversal (..\) detected"),
        (r"%2e%2e[%2f/\\]",
         "URL-encoded directory traversal detected"),
        (r"%252e%252e",
         "Double URL-encoded traversal detected"),
        (r"/etc/(passwd|shadow|hosts|sudoers)",
         "Sensitive Unix file access detected"),
        (r"/proc/(self|[0-9]+)/(environ|cmdline|fd)",
         "Linux proc filesystem access detected"),
        (r"[A-Za-z]:\\\\Windows",
         "Windows system path access detected"),
        (r"[A-Za-z]:\\\\Users\\\\.*\\\\AppData",
         "Windows user data path detected"),
        (r"~/.+/(ssh|gnupg|aws|azure)",
         "Sensitive config directory detected"),
    ],
}


def check_patterns(text: str) -> DetectionResult:
    """
    Check text against regex injection patterns.
    Fast check for known patterns - runs in <1ms.
    
    Args:
        text: The text to check for injection patterns
        
    Returns:
        DetectionResult with is_safe=True if no patterns detected,
        or is_safe=False with category and reason if pattern found
    """
    if not text:
        return DetectionResult(is_safe=True, category="", reason="")
    
    for category, patterns in INJECTION_PATTERNS.items():
        for pattern, description in patterns:
            try:
                if re.search(pattern, text, re.IGNORECASE | re.MULTILINE):
                    return DetectionResult(
                        is_safe=False,
                        category=category,
                        reason=description
                    )
            except re.error:
                # Skip invalid regex patterns
                continue
    
    return DetectionResult(is_safe=True, category="", reason="")


async def check_with_prompt_shields(texts: list[str]) -> DetectionResult:
    """
    Check texts using Azure AI Content Safety Prompt Shields.
    Detects sophisticated prompt injection and jailbreak attempts.
    
    Uses managed identity for authentication via REST API.
    The Python SDK 1.0.0 doesn't include Prompt Shields, so we call
    the REST API directly with aiohttp.
    
    Args:
        texts: List of text strings to analyze
        
    Returns:
        DetectionResult indicating if attack was detected
    """
    # Prompt Shields requires the Content Safety endpoint, not the generic AI Services endpoint
    endpoint = os.environ.get("CONTENT_SAFETY_ENDPOINT")
    if not endpoint:
        logger.warning("CONTENT_SAFETY_ENDPOINT not configured, skipping Prompt Shields")
        return DetectionResult(is_safe=True, category="", reason="")
    
    # Combine texts for analysis
    user_prompt = " ".join(texts) if texts else ""
        
    if not user_prompt.strip():
        return DetectionResult(is_safe=True, category="", reason="")
    
    try:
        # Get token using managed identity
        async with DefaultAzureCredential() as credential:
            token = await credential.get_token("https://cognitiveservices.azure.com/.default")
            
            # Construct the API URL
            # Remove trailing slash if present
            base_url = endpoint.rstrip('/')
            api_url = f"{base_url}/contentsafety/text:shieldPrompt?api-version=2024-09-01"
            
            # Prepare the request body
            request_body = {
                "userPrompt": user_prompt,
                "documents": []
            }
            
            headers = {
                "Authorization": f"Bearer {token.token}",
                "Content-Type": "application/json"
            }
            
            async with aiohttp.ClientSession() as session:
                async with session.post(api_url, json=request_body, headers=headers) as response:
                    if response.status == 200:
                        result = await response.json()
                        
                        # Check for attacks in user prompt
                        user_analysis = result.get("userPromptAnalysis", {})
                        if user_analysis.get("attackDetected"):
                            return DetectionResult(
                                is_safe=False,
                                category="prompt_injection",
                                reason="Prompt Shield detected jailbreak attack"
                            )
                        
                        # Check for attacks in documents
                        docs_analysis = result.get("documentsAnalysis", [])
                        for doc in docs_analysis:
                            if doc.get("attackDetected"):
                                return DetectionResult(
                                    is_safe=False,
                                    category="prompt_injection",
                                    reason="Prompt Shield detected document attack"
                                )
                        
                        return DetectionResult(is_safe=True, category="", reason="")
                    else:
                        error_text = await response.text()
                        logger.warning(f"Prompt Shields API returned {response.status}: {error_text}")
                        return DetectionResult(is_safe=True, category="", reason="")
                
    except Exception as e:
        logger.warning(f"Prompt Shields check failed: {e}")
        # Fail open - don't block requests if service is unavailable
        return DetectionResult(is_safe=True, category="", reason="")


def extract_texts_from_mcp_request(body: dict) -> list[str]:
    """
    Extract text content from an MCP request body.
    
    Extracts from:
    - Tool arguments
    - Resource URIs
    - Prompt content/messages
    
    Args:
        body: Parsed JSON body of MCP request
        
    Returns:
        List of text strings to check
    """
    texts_to_check = []
    
    # Extract from params.arguments (tool calls)
    params = body.get("params", {})
    arguments = params.get("arguments", {})
    if isinstance(arguments, dict):
        texts_to_check.extend(str(v) for v in arguments.values())
    elif isinstance(arguments, str):
        texts_to_check.append(arguments)
    
    # Extract from params.uri (resource requests)
    uri = params.get("uri", "")
    if uri:
        texts_to_check.append(uri)
    
    # Extract from params.messages (prompt content)
    messages = params.get("messages", [])
    for msg in messages:
        if isinstance(msg, dict):
            content = msg.get("content", "")
            if isinstance(content, str):
                texts_to_check.append(content)
            elif isinstance(content, list):
                for item in content:
                    if isinstance(item, dict) and "text" in item:
                        texts_to_check.append(item["text"])
    
    # Extract tool name (could contain injection)
    tool_name = params.get("name", "")
    if tool_name:
        texts_to_check.append(tool_name)
    
    return texts_to_check


def check_mcp_request(body: dict) -> DetectionResult:
    """
    Synchronous check of MCP request using regex patterns only.
    Use check_mcp_request_async for full hybrid check with Prompt Shields.
    
    Args:
        body: Parsed JSON body of MCP request
        
    Returns:
        DetectionResult indicating safety
    """
    texts_to_check = extract_texts_from_mcp_request(body)
    
    # Check all extracted text against regex patterns
    for text in texts_to_check:
        result = check_patterns(text)
        if not result.is_safe:
            return result
    
    return DetectionResult(is_safe=True, category="", reason="")


async def check_mcp_request_async(body: dict) -> DetectionResult:
    """
    Hybrid check of MCP request:
    1. Fast regex check first (catches 80% of attacks instantly)
    2. Prompt Shields API for sophisticated attacks (AI-powered)
    
    Args:
        body: Parsed JSON body of MCP request
        
    Returns:
        DetectionResult indicating safety
    """
    texts_to_check = extract_texts_from_mcp_request(body)
    
    # Layer 1: Fast regex check (instant, free)
    for text in texts_to_check:
        result = check_patterns(text)
        if not result.is_safe:
            logger.info(f"Regex detected: {result.category}")
            return result
    
    # Layer 2: Prompt Shields for sophisticated attacks
    prompt_result = await check_with_prompt_shields(texts_to_check)
    if not prompt_result.is_safe:
        logger.info(f"Prompt Shields detected: {prompt_result.reason}")
        return prompt_result
    
    return DetectionResult(is_safe=True, category="", reason="")
