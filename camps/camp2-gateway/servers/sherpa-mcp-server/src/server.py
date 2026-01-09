"""
Sherpa MCP Server

Provides tools for mountain climbing assistance:
- get_weather: Get current weather conditions
- check_trail_conditions: Check trail status
- get_gear_recommendations: Get gear list for conditions
"""

import os
import json
import asyncio
from datetime import datetime
from mcp.server import Server
from mcp.server.sse import SseServerTransport
from mcp.types import Tool, TextContent
from starlette.applications import Starlette
from starlette.routing import Route
from starlette.responses import Response
import uvicorn

# Initialize MCP server
server = Server("sherpa-mcp-server")

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


@server.list_tools()
async def list_tools() -> list[Tool]:
    """List available tools."""
    return [
        Tool(
            name="get_weather",
            description="Get current weather conditions for a mountain location",
            inputSchema={
                "type": "object",
                "properties": {
                    "location": {
                        "type": "string",
                        "description": "Location to get weather for (summit, base, camp1)",
                        "enum": ["summit", "base", "camp1"]
                    }
                },
                "required": ["location"]
            }
        ),
        Tool(
            name="check_trail_conditions",
            description="Check current conditions and hazards for a specific trail",
            inputSchema={
                "type": "object",
                "properties": {
                    "trail_id": {
                        "type": "string",
                        "description": "Trail identifier (summit-trail, base-trail, ridge-walk)",
                        "enum": ["summit-trail", "base-trail", "ridge-walk"]
                    }
                },
                "required": ["trail_id"]
            }
        ),
        Tool(
            name="get_gear_recommendations",
            description="Get recommended gear list for specific climbing conditions",
            inputSchema={
                "type": "object",
                "properties": {
                    "condition_type": {
                        "type": "string",
                        "description": "Type of climbing conditions (winter, summer, technical)",
                        "enum": ["winter", "summer", "technical"]
                    }
                },
                "required": ["condition_type"]
            }
        )
    ]


@server.call_tool()
async def call_tool(name: str, arguments: dict) -> list[TextContent]:
    """Execute a tool call."""
    if name == "get_weather":
        location = arguments.get("location", "base")
        weather = WEATHER_DATA.get(location, WEATHER_DATA["base"])
        result = {
            "location": location,
            "timestamp": datetime.now().isoformat(),
            **weather
        }
        return [TextContent(
            type="text",
            text=f"Weather at {location}:\n" + json.dumps(result, indent=2)
        )]
    
    elif name == "check_trail_conditions":
        trail_id = arguments.get("trail_id", "base-trail")
        conditions = TRAIL_CONDITIONS.get(trail_id, TRAIL_CONDITIONS["base-trail"])
        result = {
            "trail_id": trail_id,
            "checked_at": datetime.now().isoformat(),
            **conditions
        }
        return [TextContent(
            type="text",
            text=f"Trail conditions for {trail_id}:\n" + json.dumps(result, indent=2)
        )]
    
    elif name == "get_gear_recommendations":
        condition_type = arguments.get("condition_type", "summer")
        gear = GEAR_RECOMMENDATIONS.get(condition_type, GEAR_RECOMMENDATIONS["summer"])
        result = {
            "condition_type": condition_type,
            "gear_list": gear
        }
        return [TextContent(
            type="text",
            text=f"Gear recommendations for {condition_type} climbing:\n" + json.dumps(result, indent=2)
        )]
    
    else:
        return [TextContent(
            type="text",
            text=f"Unknown tool: {name}"
        )]


# HTTP transport setup
async def handle_sse(request):
    """Handle SSE connections for MCP."""
    async with SseServerTransport("/mcp") as transport:
        await server.run(
            transport,
            server.create_initialization_options()
        )
    return Response()


async def handle_messages(request):
    """Handle POST messages for MCP."""
    body = await request.body()
    # Process MCP messages
    return Response()


async def health_check(request):
    """Health check endpoint."""
    return Response(
        content=json.dumps({"status": "healthy", "service": "sherpa-mcp-server"}),
        media_type="application/json"
    )


# Create Starlette app
app = Starlette(
    routes=[
        Route("/mcp", handle_sse, methods=["GET"]),
        Route("/mcp", handle_messages, methods=["POST"]),
        Route("/health", health_check, methods=["GET"]),
    ]
)


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run(app, host="0.0.0.0", port=port)
