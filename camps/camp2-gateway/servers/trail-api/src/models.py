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


class Permit(BaseModel):
    """Issued permit model."""
    id: str
    trail_id: str
    trail_name: str
    hiker_name: str
    hiker_email: str
    planned_date: str
    status: str  # pending, active, expired, cancelled
    issued_at: str


class PermitRequest(BaseModel):
    """Request model for new permit."""
    trail_id: str
    hiker_name: str
    hiker_email: str
    planned_date: str
    emergency_contact: Optional[str] = None
    group_size: int = 1


class PermitResponse(BaseModel):
    """Response model for permit operations."""
    success: bool
    message: str
    permit: Optional[Permit] = None
