"""
Trail API - FastAPI application

Provides REST endpoints for trail information:
- GET /trails - List all trails
- GET /trails/{id} - Get trail details
- GET /trails/{id}/conditions - Current conditions
- GET /trails/{id}/permits - Permit requirements (protected)
"""

import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from src.routes import trails, permits

app = FastAPI(
    title="Trail API",
    description="REST API for mountain trail information",
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
app.include_router(permits.router, prefix="/trails", tags=["permits"])


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
            "/trails": "List all trails",
            "/trails/{id}": "Get trail details",
            "/trails/{id}/conditions": "Get trail conditions",
            "/trails/{id}/permits": "Get permit info (protected)"
        }
    }
