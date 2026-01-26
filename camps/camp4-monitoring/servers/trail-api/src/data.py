"""Static data for Trail API."""

from datetime import datetime
from src.models import Trail, TrailConditions, Permit, PermitHolder

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

# Permits database (in-memory for demo, backend system would manage this)
PERMITS_DB: dict[str, Permit] = {
    "TRAIL-2024-001": Permit(
        id="TRAIL-2024-001",
        trail_id="summit-trail",
        trail_name="Summit Ridge Trail",
        hiker_name="John Smith",
        hiker_email="john.smith@example.com",
        planned_date="2025-01-15",
        status="active",
        issued_at="2025-01-08T10:30:00"
    ),
    "TRAIL-2024-002": Permit(
        id="TRAIL-2024-002",
        trail_id="ridge-walk",
        trail_name="Alpine Ridge Walk",
        hiker_name="Jane Doe",
        hiker_email="jane.doe@example.com",
        planned_date="2025-01-12",
        status="active",
        issued_at="2025-01-07T14:15:00"
    ),
}

# Permit holders with PII - FOR DEMONSTRATION OF PII LEAKAGE
# In production, this data would be in a secure database with proper access controls
PERMIT_HOLDERS: dict[str, PermitHolder] = {
    "TRAIL-2024-001": PermitHolder(
        permit_id="TRAIL-2024-001",
        holder_name="John Smith",
        email="john.smith@example.com",
        phone="555-123-4567",
        ssn="123-45-6789",  # Sensitive PII!
        address="123 Mountain View Dr, Denver, CO 80202",
        emergency_contact_name="Mary Smith",
        emergency_contact_phone="555-987-6543"
    ),
    "TRAIL-2024-002": PermitHolder(
        permit_id="TRAIL-2024-002",
        holder_name="Jane Doe",
        email="jane.doe@example.com",
        phone="555-234-5678",
        ssn="987-65-4321",  # Sensitive PII!
        address="456 Alpine Way, Boulder, CO 80301",
        emergency_contact_name="John Doe",
        emergency_contact_phone="555-876-5432"
    ),
}
