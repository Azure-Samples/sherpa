"""Static data for Trail API."""

from datetime import datetime
from src.models import Trail, TrailConditions, PermitInfo

# Trail data
TRAILS: dict[str, Trail] = {
    "summit-trail": Trail(
        id="summit-trail",
        name="Summit Ridge Trail",
        difficulty="Expert",
        distance_miles=8.5,
        elevation_gain_ft=4200,
        estimated_time_hours=8.0,
        permit_required=True
    ),
    "base-trail": Trail(
        id="base-trail",
        name="Base Camp Loop",
        difficulty="Beginner",
        distance_miles=2.3,
        elevation_gain_ft=350,
        estimated_time_hours=1.5,
        permit_required=False
    ),
    "ridge-walk": Trail(
        id="ridge-walk",
        name="Alpine Ridge Walk",
        difficulty="Intermediate",
        distance_miles=5.2,
        elevation_gain_ft=1800,
        estimated_time_hours=4.0,
        permit_required=True
    ),
}

# Conditions data
CONDITIONS: dict[str, TrailConditions] = {
    "summit-trail": TrailConditions(
        status="open",
        hazards=["ice patches", "high winds", "limited visibility above 12,000ft"],
        last_updated="2025-01-08",
        weather="Partly cloudy, winds 35mph",
        notes="Technical gear required. Crampons recommended for icy sections."
    ),
    "base-trail": TrailConditions(
        status="open",
        hazards=[],
        last_updated="2025-01-08",
        weather="Clear, winds 5-10mph",
        notes="Well-maintained trail, suitable for all skill levels."
    ),
    "ridge-walk": TrailConditions(
        status="limited",
        hazards=["snow coverage", "slippery conditions"],
        last_updated="2025-01-07",
        weather="Light snow, winds 20mph",
        notes="Trail partially covered with snow. Trekking poles recommended."
    ),
}

# Permit data
PERMITS: dict[str, PermitInfo] = {
    "summit-trail": PermitInfo(
        required=True,
        type="Summit Access Permit",
        cost_usd=50.00,
        application_url="https://example.com/permits/summit",
        processing_time_days=7,
        requirements=[
            "Valid government-issued ID",
            "Emergency contact information",
            "Proof of technical climbing experience",
            "Summit attempt date and intended route"
        ]
    ),
    "base-trail": PermitInfo(
        required=False,
        type="None",
        cost_usd=0.00,
        application_url="",
        processing_time_days=0,
        requirements=[]
    ),
    "ridge-walk": PermitInfo(
        required=True,
        type="Alpine Zone Day Pass",
        cost_usd=15.00,
        application_url="https://example.com/permits/alpine",
        processing_time_days=1,
        requirements=[
            "Valid government-issued ID",
            "Emergency contact information"
        ]
    ),
}
