"""
Sherpa MCP Server

Provides tools for mountain climbing assistance:
- get_weather: Get current weather conditions
- check_trail_conditions: Check trail status
- get_gear_recommendations: Get gear list for conditions

This server is protected by APIM gateway security (OAuth, Content Safety, I/O Security).
"""

import os
import json
import logging
from datetime import datetime
from fastmcp import FastMCP
import uvicorn
from .sanitizer import sanitize_output, SANITIZE_ENABLED

# Configure OpenTelemetry for Azure Monitor (Application Insights)
# This enables request tracing, custom spans for each MCP tool, and unified telemetry
if os.environ.get("APPLICATIONINSIGHTS_CONNECTION_STRING"):
    from azure.monitor.opentelemetry import configure_azure_monitor
    from opentelemetry import trace
    
    configure_azure_monitor(
        connection_string=os.environ["APPLICATIONINSIGHTS_CONNECTION_STRING"],
        logger_name="sherpa-mcp-server",
    )
    tracer = trace.get_tracer("sherpa-mcp-server")
else:
    tracer = None

# Configure structured logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger("sherpa-mcp-server")

# Create FastMCP server
mcp = FastMCP("Sherpa MCP Server")

# Sample data
WEATHER_DATA = {
    "summit": {"temp_f": 28, "wind_mph": 35, "conditions": "Partly cloudy", "visibility": "Good"},
    "base": {"temp_f": 45, "wind_mph": 15, "conditions": "Clear", "visibility": "Excellent"},
    "camp1": {"temp_f": 38, "wind_mph": 20, "conditions": "Light snow", "visibility": "Moderate"},
}

TRAIL_CONDITIONS = {
    "summit-trail": {"status": "open", "hazards": ["ice patches", "high winds"], "last_updated": "2025-01-08"},
    "base-trail": {"status": "open", "hazards": [], "last_updated": "2025-01-08"},
    "ridge-walk": {"status": "limited", "hazards": ["snow coverage"], "last_updated": "2025-01-07"},
}

GEAR_RECOMMENDATIONS = {
    "winter": ["insulated jacket", "crampons", "ice axe", "goggles", "thermal layers"],
    "summer": ["light jacket", "sun hat", "sunscreen", "water bottles", "trekking poles"],
    "technical": ["harness", "rope", "carabiners", "helmet", "belay device"],
}


@mcp.tool()
def get_weather(location: str = "base") -> str:
    """
    Get current weather conditions for a mountain location.
    
    Args:
        location: Location to get weather for (summit, base, camp1)
    
    Returns:
        Weather data as JSON string
    """
    # Create custom span for tracing
    span_context = tracer.start_as_current_span("mcp_tool_get_weather") if tracer else None
    if span_context:
        span_context.__enter__()
        span = trace.get_current_span()
        span.set_attribute("mcp.tool", "get_weather")
        span.set_attribute("mcp.tool.location", location)
    
    try:
        weather = WEATHER_DATA.get(location, WEATHER_DATA["base"])
        result = {
            "location": location,
            "timestamp": datetime.now().isoformat(),
            **weather
        }
        logger.info(f"get_weather called for location={location}")
        return json.dumps(result, indent=2)
    finally:
        if span_context:
            span_context.__exit__(None, None, None)


@mcp.tool()
def check_trail_conditions(trail_id: str = "base-trail") -> str:
    """
    Check current conditions and hazards for a specific trail.
    
    Args:
        trail_id: Trail identifier (summit-trail, base-trail, ridge-walk)
    
    Returns:
        Trail conditions as JSON string
    """
    # Create custom span for tracing
    span_context = tracer.start_as_current_span("mcp_tool_check_trail_conditions") if tracer else None
    if span_context:
        span_context.__enter__()
        span = trace.get_current_span()
        span.set_attribute("mcp.tool", "check_trail_conditions")
        span.set_attribute("mcp.tool.trail_id", trail_id)
    
    try:
        conditions = TRAIL_CONDITIONS.get(trail_id, TRAIL_CONDITIONS["base-trail"])
        result = {
            "trail_id": trail_id,
            "checked_at": datetime.now().isoformat(),
            **conditions
        }
        logger.info(f"check_trail_conditions called for trail_id={trail_id}")
        return json.dumps(result, indent=2)
    finally:
        if span_context:
            span_context.__exit__(None, None, None)


@mcp.tool()
def get_gear_recommendations(condition_type: str = "summer") -> str:
    """
    Get recommended gear list for specific climbing conditions.
    
    Args:
        condition_type: Type of climbing conditions (winter, summer, technical)
    
    Returns:
        Gear recommendations as JSON string
    """
    # Create custom span for tracing
    span_context = tracer.start_as_current_span("mcp_tool_get_gear_recommendations") if tracer else None
    if span_context:
        span_context.__enter__()
        span = trace.get_current_span()
        span.set_attribute("mcp.tool", "get_gear_recommendations")
        span.set_attribute("mcp.tool.condition_type", condition_type)
    
    try:
        gear = GEAR_RECOMMENDATIONS.get(condition_type, GEAR_RECOMMENDATIONS["summer"])
        result = {
            "condition_type": condition_type,
            "gear_list": gear
        }
        logger.info(f"get_gear_recommendations called for condition_type={condition_type}")
        return json.dumps(result, indent=2)
    finally:
        if span_context:
            span_context.__exit__(None, None, None)


@mcp.tool()
async def get_guide_contact(guide_id: str = "guide-001") -> str:
    """
    Get contact information for a mountain guide.
    
    Args:
        guide_id: Guide identifier
    
    Returns:
        Guide contact information as JSON string (PII sanitized by default)
    """
    # Create custom span for tracing
    span_context = tracer.start_as_current_span("mcp_tool_get_guide_contact") if tracer else None
    if span_context:
        span_context.__enter__()
        span = trace.get_current_span()
        span.set_attribute("mcp.tool", "get_guide_contact")
        span.set_attribute("mcp.tool.guide_id", guide_id)
        span.set_attribute("mcp.tool.sanitize_enabled", SANITIZE_ENABLED)
    
    try:
        # Sample guide data with PII for testing output sanitization
        guides = {
            "guide-001": {
                "guide_id": "guide-001",
                "name": "Sarah Johnson",
                "email": "sarah.johnson@mountainguides.com",
                "phone": "303-555-1234",
                "ssn": "987-65-4321",
                "certification": "AMGA Certified",
                "emergency_contact": "Mike Johnson",
                "emergency_phone": "303-555-5678",
                "address": "456 Alpine Way, Boulder, CO 80302"
            },
            "guide-002": {
                "guide_id": "guide-002",
                "name": "Tom Martinez",
                "email": "tom.m@summitexpeditions.com",
                "phone": "720-555-9876",
                "ssn": "123-45-6789",
                "certification": "IFMGA Licensed",
                "emergency_contact": "Lisa Martinez",
                "emergency_phone": "720-555-4321",
                "address": "789 Peak Street, Denver, CO 80203"
            }
        }
        guide = guides.get(guide_id, guides["guide-001"])
        raw_json = json.dumps(guide, indent=2)
        logger.info(f"get_guide_contact called for guide_id={guide_id}")
        
        # Sanitize PII before returning (enabled by default in Camp 4)
        return await sanitize_output(raw_json)
    finally:
        if span_context:
            span_context.__exit__(None, None, None)


if __name__ == "__main__":
    import uvicorn
    
    port = int(os.environ.get("PORT", 8000))
    
    print("=" * 70)
    print("Sherpa MCP Server - Camp 4: Monitoring & Telemetry")
    print("=" * 70)
    print(f"Server Name: {mcp.name}")
    print("Listening on: http://0.0.0.0:" + str(port))
    print("")
    print("Security: Protected by APIM gateway")
    print("  - OAuth 2.0 authentication")
    print("  - Azure AI Content Safety (Layer 1)")
    print("  - Input validation function (Layer 2)")
    print("  - Server-side PII sanitization: " + ("ENABLED" if SANITIZE_ENABLED else "DISABLED"))
    print("")
    print("Telemetry: " + ("Enabled (Azure Monitor)" if tracer else "Disabled (no connection string)"))
    print("")
    print("Available Tools:")
    print("   - get_weather(location)")
    print("   - check_trail_conditions(trail_id)")
    print("   - get_gear_recommendations(condition_type)")
    print("   - get_guide_contact(guide_id)")
    print("=" * 70)
    print("")
    
    if tracer:
        logger.info("OpenTelemetry instrumentation enabled for Sherpa MCP Server")
    
    # Create ASGI app with streamable-http transport
    app = mcp.http_app(path="/mcp", transport="streamable-http")
    
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=port,
        log_level="info"
    )
