"""Protected permit endpoint - requires OAuth token."""

import os
from fastapi import APIRouter, HTTPException, Depends, Header
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from typing import Optional
from src.models import PermitInfo
from src.data import TRAILS, PERMITS

router = APIRouter()
security = HTTPBearer(auto_error=False)


async def verify_token(
    authorization: Optional[HTTPAuthorizationCredentials] = Depends(security),
    x_forwarded_authorization: Optional[str] = Header(None, alias="X-Forwarded-Authorization")
):
    """
    Verify OAuth token from Authorization header or X-Forwarded-Authorization header.
    
    In production, this would validate the JWT token against Entra ID.
    For this workshop, we accept tokens forwarded by APIM Credential Manager.
    """
    token = None
    
    # Check X-Forwarded-Authorization first (from APIM Credential Manager)
    if x_forwarded_authorization:
        token = x_forwarded_authorization.replace("Bearer ", "")
    # Fall back to Authorization header
    elif authorization:
        token = authorization.credentials
    
    if not token:
        raise HTTPException(
            status_code=401,
            detail="Missing authentication token"
        )
    
    # In production, validate JWT here
    # For workshop: accept any token as valid
    return token


@router.get("/{trail_id}/permits", response_model=PermitInfo)
async def get_trail_permits(
    trail_id: str,
    token: str = Depends(verify_token)
):
    """
    Get permit information for a specific trail.
    
    **Protected Endpoint** - Requires OAuth token
    
    Returns:
    - Permit requirements
    - Application process
    - Cost and processing time
    - Required documentation
    """    
    if trail_id not in TRAILS:
        raise HTTPException(status_code=404, detail="Trail not found")
    
    if trail_id not in PERMITS:
        raise HTTPException(status_code=404, detail="Permit info not found")
    
    return PERMITS[trail_id]
