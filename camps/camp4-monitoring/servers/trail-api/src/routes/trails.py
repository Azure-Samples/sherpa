"""Public trail endpoints."""

from fastapi import APIRouter, HTTPException, Path
from src.models import Trail, TrailConditions
from src.data import TRAILS, CONDITIONS

router = APIRouter()


@router.get("", response_model=list[Trail], operation_id="list_trails")
async def list_trails():
    """
    List all available hiking trails.
    
    Returns a list of all trails with basic information including
    difficulty, distance, and permit requirements.
    """
    return list(TRAILS.values())


@router.get("/{trail_id}", response_model=Trail, operation_id="get_trail")
async def get_trail(trail_id: str = Path(..., pattern=r'^[a-z]+-[a-z]+$')):
    """
    Get details for a specific trail.
    
    Returns trail details including difficulty, distance, elevation gain,
    estimated time, and whether a permit is required.
    """
    if trail_id not in TRAILS:
        raise HTTPException(status_code=404, detail="Trail not found")
    return TRAILS[trail_id]


@router.get("/{trail_id}/conditions", response_model=TrailConditions, operation_id="check_conditions")
async def check_conditions(trail_id: str = Path(..., pattern=r'^[a-z]+-[a-z]+$')):
    """
    Get current trail conditions and hazards.
    
    Returns:
    - Current status (open/closed/limited)
    - Active hazards and warnings
    - Weather conditions at trailhead
    - Recent ranger notes and updates
    """    
    if trail_id not in CONDITIONS:
        raise HTTPException(status_code=404, detail="Trail not found")
    return CONDITIONS[trail_id]
