"""Public trail endpoints."""

from fastapi import APIRouter, HTTPException
from src.models import Trail, TrailConditions
from src.data import TRAILS, CONDITIONS

router = APIRouter()


@router.get("", response_model=list[Trail])
async def list_trails():
    """
    List all available trails.
    
    Returns a list of all trails with basic information.
    """
    return list(TRAILS.values())


@router.get("/{trail_id}", response_model=Trail)
async def get_trail(trail_id: str):
    """
    Get detailed information about a specific trail.
    
    Returns trail details including difficulty, distance, and elevation.
    """
    if trail_id not in TRAILS:
        raise HTTPException(status_code=404, detail="Trail not found")
    return TRAILS[trail_id]


@router.get("/{trail_id}/conditions", response_model=TrailConditions)
async def get_trail_conditions(trail_id: str):
    """
    Get current conditions for a specific trail.
    
    Returns:
    - Current status (open/closed/limited)
    - Active hazards
    - Weather conditions
    - Recent updates
    """    
    if trail_id not in CONDITIONS:
        raise HTTPException(status_code=404, detail="Trail not found")
    return CONDITIONS[trail_id]
