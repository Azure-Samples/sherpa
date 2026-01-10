"""
Trail API - FastAPI application

REST API for trail information and permit management.

Endpoints:
- GET  /trails              - List all available hiking trails
- GET  /trails/{id}         - Get details for a specific trail
- GET  /trails/{id}/conditions - Current trail conditions and hazards
- GET  /permits/{id}        - Retrieve a trail permit
- POST /permits             - Request a new trail permit

Note: Permit endpoints call a backend permit system that requires an API key.
In Waypoint 2.2, we'll use APIM Credential Manager to securely manage this.
"""

import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from src.routes import trails, permits

app = FastAPI(
    title="Trail API",
    description="REST API for mountain trail information and permit management",
    version="1.0.0"
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(trails.router, prefix="/trails", tags=["trails"])
app.include_router(permits.router, prefix="/permits", tags=["permits"])


@app.get("/health")
async def health_check():
    """Health check endpoint."""
    return {"status": "healthy", "service": "trail-api"}


@app.get("/")
async def root():
    """Root endpoint with API info."""
    return {
        "service": "trail-api",
        "version": "1.0.0",
        "endpoints": {
            "GET /trails": "List all available hiking trails",
            "GET /trails/{id}": "Get details for a specific trail",
            "GET /trails/{id}/conditions": "Current trail conditions and hazards",
            "GET /permits/{id}": "Retrieve a trail permit",
            "POST /permits": "Request a new trail permit"
        }
    }
