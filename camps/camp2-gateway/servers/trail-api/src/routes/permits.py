"""
Permit endpoints - calls backend permit system.

These endpoints require an API key to the backend permit management system.
In Waypoint 2.2, we'll use APIM Credential Manager to securely manage this key.
"""

import os
from fastapi import APIRouter, HTTPException, Header
from typing import Optional
from datetime import datetime
from src.models import Permit, PermitRequest, PermitResponse
from src.data import PERMITS_DB

router = APIRouter()

# Backend permit system API key (would come from environment/Key Vault in production)
# For now, we'll simulate this - APIM Credential Manager will handle this securely later
BACKEND_API_KEY = os.environ.get("PERMIT_SYSTEM_API_KEY", "demo-permit-key-12345")


def verify_backend_api_key(x_backend_api_key: Optional[str] = Header(None, alias="X-Backend-Api-Key")):
    """
    Verify API key for backend permit system.
    
    In production, this API would call an external permit management system
    that requires its own API key. APIM Credential Manager will inject this
    key automatically in Waypoint 2.2.
    
    For now, we accept requests without the key for demo purposes.
    """
    # In production: validate against BACKEND_API_KEY
    # For workshop demo: always allow (APIM will handle auth)
    return True


@router.get("/{permit_id}", response_model=Permit, operation_id="get_permit")
async def get_permit(permit_id: str):
    """
    Retrieve a trail permit by ID.
    
    Returns the permit details including:
    - Permit holder information
    - Valid dates and trail access
    - Permit status (active/expired/pending)
    
    Note: This endpoint calls the backend permit system which requires
    an API key. In production, use APIM Credential Manager to handle this.
    """
    if permit_id not in PERMITS_DB:
        raise HTTPException(status_code=404, detail="Permit not found")
    
    return PERMITS_DB[permit_id]


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
    
    Note: This endpoint calls the backend permit system which requires
    an API key. In production, use APIM Credential Manager to handle this.
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
    new_permit_id = f"PRM-{datetime.now().strftime('%Y%m%d')}-{len(PERMITS_DB) + 1:04d}"
    
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
