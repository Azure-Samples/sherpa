"""
Sherpa MCP Server

Provides tools for mountain climbing assistance:
- get_weather: Get current weather conditions
- check_trail_conditions: Check trail status
- get_gear_recommendations: Get gear list for conditions

⚠️ SECURITY WARNING: This server has NO AUTHENTICATION
This is intentionally insecure for Waypoint 1.1 demonstration.
"""

import os
import json
from datetime import datetime
from fastmcp import FastMCP
import uvicorn

# Create FastMCP server WITHOUT authentication (insecure for demo)
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
    weather = WEATHER_DATA.get(location, WEATHER_DATA["base"])
    result = {
        "location": location,
        "timestamp": datetime.now().isoformat(),
        **weather
    }
    return json.dumps(result, indent=2)


@mcp.tool()
def check_trail_conditions(trail_id: str = "base-trail") -> str:
    """
    Check current conditions and hazards for a specific trail.
    
    Args:
        trail_id: Trail identifier (summit-trail, base-trail, ridge-walk)
    
    Returns:
        Trail conditions as JSON string
    """
    conditions = TRAIL_CONDITIONS.get(trail_id, TRAIL_CONDITIONS["base-trail"])
    result = {
        "trail_id": trail_id,
        "checked_at": datetime.now().isoformat(),
        **conditions
    }
    return json.dumps(result, indent=2)


@mcp.tool()
def get_gear_recommendations(condition_type: str = "summer") -> str:
    """
    Get recommended gear list for specific climbing conditions.
    
    Args:
        condition_type: Type of climbing conditions (winter, summer, technical)
    
    Returns:
        Gear recommendations as JSON string
    """
    gear = GEAR_RECOMMENDATIONS.get(condition_type, GEAR_RECOMMENDATIONS["summer"])
    result = {
        "condition_type": condition_type,
        "gear_list": gear
    }
    return json.dumps(result, indent=2)


if __name__ == "__main__":
    import uvicorn
    
    port = int(os.environ.get("PORT", 8000))
    
    print("=" * 70)
    print("⚠️  Sherpa MCP Server - NO AUTHENTICATION (Waypoint 1.1)")
    print("=" * 70)
    print(f"Server Name: {mcp.name}")
    print("Listening on: http://0.0.0.0:" + str(port))
    print("")
    print("❌ NO AUTHENTICATION")
    print("   All requests are accepted without credentials")
    print("   This is intentionally insecure for demonstration!")
    print("")
    print("Available Tools:")
    print("   - get_weather(location)")
    print("   - check_trail_conditions(trail_id)")
    print("   - get_gear_recommendations(condition_type)")
    print("=" * 70)
    print("")
    
    # Create ASGI app with streamable-http transport
    app = mcp.http_app(path="/mcp", transport="streamable-http")
    
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=port,
        log_level="info"
    )

