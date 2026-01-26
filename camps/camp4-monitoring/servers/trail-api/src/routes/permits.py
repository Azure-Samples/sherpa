"""
Permit endpoints - including PII-leaking endpoint for Camp 4 demo.

This module demonstrates MCP-03 (Tool Poisoning) vulnerability where
an API returns sensitive PII that should be redacted before being
exposed through the MCP gateway.
"""

import os
import re
from fastapi import APIRouter, HTTPException, Header, Path
from typing import Optional
from datetime import datetime
from src.models import Permit, PermitRequest, PermitResponse, PermitHolder
from src.data import PERMITS_DB, PERMIT_HOLDERS

router = APIRouter()

# Backend permit system API key (would come from environment/Key Vault in production)
BACKEND_API_KEY = os.environ.get("PERMIT_SYSTEM_API_KEY", "demo-permit-key-12345")


@router.get("/{permit_id}", response_model=Permit, operation_id="get_permit")
async def get_permit(permit_id: str = Path(..., pattern=r'^TRAIL-\d{4}-\d{3}$')):
    """
    Retrieve a trail permit by ID.
    
    Returns the permit details including:
    - Permit holder information
    - Valid dates and trail access
    - Permit status (active/expired/pending)
    """
    if permit_id not in PERMITS_DB:
        raise HTTPException(status_code=404, detail="Permit not found")
    
    return PERMITS_DB[permit_id]


@router.get("/{permit_id}/holder", response_model=PermitHolder, operation_id="get_permit_holder")
async def get_permit_holder(permit_id: str = Path(..., pattern=r'^TRAIL-\d{4}-\d{3}$')):
    """
    Get permit holder details including PII.
    
    ⚠️ SECURITY WARNING: This endpoint returns sensitive PII including:
    - Social Security Number (SSN)
    - Email address
    - Phone number
    - Physical address
    
    This endpoint is intentionally vulnerable for Camp 4 demonstration.
    Without APIM output sanitization, this PII leaks to clients.
    
    Returns permit holder details (intentionally includes PII for demo).
    """
    if permit_id not in PERMIT_HOLDERS:
        raise HTTPException(status_code=404, detail="Permit holder not found")
    
    return PERMIT_HOLDERS[permit_id]


@router.post("", response_model=PermitResponse, operation_id="request_permit")
async def request_permit(request: PermitRequest):
    """
    Request a new trail permit.
    
    Submit a permit application for a specific trail. The request will be
    processed by the backend permit system.
    
    Required fields:
    - trail_id: The trail requiring a permit
    - hiker_name: Full name of permit holder  
    - hiker_email: Contact email
    - planned_date: Intended hiking date
    """
    # Validate trail exists
    from src.data import TRAILS
    if request.trail_id not in TRAILS:
        raise HTTPException(status_code=400, detail=f"Unknown trail: {request.trail_id}")
    
    # Check if trail requires permit
    trail = TRAILS[request.trail_id]
    if not trail.permit_required:
        raise HTTPException(
            status_code=400, 
            detail=f"Trail '{trail.name}' does not require a permit"
        )
    
    # Generate permit ID (in production, backend system would do this)
    new_permit_id = f"TRAIL-{datetime.now().strftime('%Y')}-{len(PERMITS_DB) + 1:03d}"
    
    # Create permit (in production, this would call the backend permit system)
    new_permit = Permit(
        id=new_permit_id,
        trail_id=request.trail_id,
        trail_name=trail.name,
        hiker_name=request.hiker_name,
        hiker_email=request.hiker_email,
        planned_date=request.planned_date,
        status="pending",
        issued_at=datetime.now().isoformat()
    )
    
    # Store permit (in-memory for demo)
    PERMITS_DB[new_permit_id] = new_permit
    
    return PermitResponse(
        success=True,
        message=f"Permit request submitted successfully",
        permit=new_permit
    )
