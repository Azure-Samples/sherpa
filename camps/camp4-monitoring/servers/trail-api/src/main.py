"""
Trail API - FastAPI application

REST API for trail information and permit management.
Includes PII-returning endpoint for Camp 4 Monitoring demonstration.

Endpoints:
- GET  /trails              - List all available hiking trails
- GET  /trails/{id}         - Get details for a specific trail
- GET  /trails/{id}/conditions - Current trail conditions and hazards
- GET  /permits/{id}        - Retrieve a trail permit
- GET  /permits/{id}/holder - Get permit holder details (INCLUDES PII!)
- POST /permits             - Request a new trail permit
"""

import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from src.routes import trails, permits

app = FastAPI(
    title="Trail API",
    description="REST API for mountain trail information and permit management. Includes PII demonstration endpoint for Camp 4.",
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
        "camp": "camp4-monitoring",
        "endpoints": {
            "GET /trails": "List all available hiking trails",
            "GET /trails/{id}": "Get details for a specific trail",
            "GET /trails/{id}/conditions": "Current trail conditions and hazards",
            "GET /permits/{id}": "Retrieve a trail permit",
            "GET /permits/{id}/holder": "Get permit holder details (PII demo)",
            "POST /permits": "Request a new trail permit"
        },
        "security_note": "The /permits/{id}/holder endpoint returns PII for Camp 4 demonstration. APIM output sanitization should redact sensitive data."
    }
