"""Data models for Trail API."""

from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime
import re


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
    trail_id: str = Field(..., pattern=r'^[a-z]+-[a-z]+$')
    hiker_name: str = Field(..., min_length=2, max_length=100)
    hiker_email: str = Field(..., pattern=r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
    planned_date: str = Field(..., pattern=r'^\d{4}-\d{2}-\d{2}$')
    emergency_contact: Optional[str] = None
    group_size: int = Field(default=1, ge=1, le=12)


class PermitResponse(BaseModel):
    """Response model for permit operations."""
    success: bool
    message: str
    permit: Optional[Permit] = None


class PermitHolder(BaseModel):
    """
    Permit holder details including PII.
    
    WARNING: This model contains sensitive personal information.
    In production, this data should be handled with appropriate security controls.
    Camp 4 demonstrates how APIM output sanitization redacts PII.
    """
    permit_id: str
    holder_name: str
    email: str
    phone: str
    ssn: str  # Social Security Number - sensitive PII!
    address: str
    emergency_contact_name: Optional[str] = None
    emergency_contact_phone: Optional[str] = None
