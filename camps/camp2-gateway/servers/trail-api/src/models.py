"""Data models for Trail API."""

from pydantic import BaseModel
from typing import Optional
from datetime import datetime


class Trail(BaseModel):
    """Trail information model."""
    id: str
    name: str
    difficulty: str
    distance_miles: float
    elevation_gain_ft: int
    estimated_time_hours: float
    permit_required: bool = False


class TrailConditions(BaseModel):
    """Current trail conditions model."""
    status: str
    hazards: list[str]
    last_updated: str
    weather: Optional[str] = None
    notes: Optional[str] = None


class PermitInfo(BaseModel):
    """Permit information model."""
    required: bool
    type: str
    cost_usd: float
    application_url: str
    processing_time_days: int
    requirements: list[str]
