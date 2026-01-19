"""
Injection Pattern Detection Module

Organized by OWASP MCP risk category for clear documentation and maintenance.
These patterns are designed to catch advanced attacks that bypass basic content safety filters.
"""

import re
from typing import NamedTuple


class DetectionResult(NamedTuple):
    """Result of pattern detection."""
    is_safe: bool
    category: str
    reason: str


# Organized by OWASP MCP risk category
INJECTION_PATTERNS: dict[str, list[tuple[str, str]]] = {
    # MCP-06: Prompt Injection - AI instruction manipulation
    "prompt_injection": [
        (r"then\s+(also\s+)?(list|show|retrieve|summarize|dump|display|output|print)", 
         "Chained instruction pattern detected"),
        (r"after\s+that\s+(list|show|retrieve|summarize|dump)",
         "Sequential instruction injection detected"),
        (r"first\s+.{1,50}\s+then\s+.{1,50}",
         "Multi-step instruction injection detected"),
        (r"ignore\s+(all\s+)?(previous\s+)?instructions?",
         "Instruction override attempt detected"),
        (r"you\s+are\s+now\s+(in\s+)?admin",
         "Role elevation injection detected"),
        (r"reveal\s+(your\s+)?(system\s+)?prompt",
         "System prompt extraction attempt detected"),
        (r"forget\s+(everything|all|prior)",
         "Context clearing injection detected"),
        (r"disregard\s+(all\s+)?(prior|previous)",
         "Instruction disregard attempt detected"),
        (r"new\s+instructions?\s*:",
         "Instruction injection marker detected"),
        (r"<\s*(system|assistant|user)\s*>",
         "Role tag injection detected"),
        (r"act\s+as\s+(if\s+)?(you\s+)?(are|were)\s+",
         "Role assumption injection detected"),
        (r"pretend\s+(to\s+be|you\s+are)",
         "Persona injection detected"),
    ],
    
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
    Check text against all injection patterns.
    
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


def check_mcp_request(body: dict) -> DetectionResult:
    """
    Check an MCP request body for injection patterns.
    
    Extracts and checks:
    - Tool arguments
    - Resource URIs
    - Prompt content
    
    Args:
        body: Parsed JSON body of MCP request
        
    Returns:
        DetectionResult indicating safety
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
    
    # Check all extracted text
    for text in texts_to_check:
        result = check_patterns(text)
        if not result.is_safe:
            return result
    
    return DetectionResult(is_safe=True, category="", reason="")
