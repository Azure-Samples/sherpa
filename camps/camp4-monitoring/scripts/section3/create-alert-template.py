#!/usr/bin/env python3
"""Generate ARM template for MCP Security Alert Rules.

Azure Monitor OpenTelemetry for Python stores custom_dimensions as a Python dict string
with single quotes and None values. We use replace_string() in KQL to parse it properly.

Usage:
    python3 create-alert-template.py <workspace_id> <action_group_id> <location>
"""

import json
import sys


def create_template(workspace_id: str, action_group_id: str, location: str) -> dict:
    """Create ARM template for alert rules."""
    
    # KQL for high attack volume
    # Returns individual attack events - the alert's Count aggregation counts the rows
    # Note: Properties is a JSON string, custom_dimensions contains Python dict string
    high_attack_query = """AppTraces
| where Properties has 'custom_dimensions'
| extend CustomDims = parse_json(replace_string(replace_string(tostring(parse_json(Properties).custom_dimensions), "'", '"'), "None", "null"))
| extend EventType = tostring(CustomDims.event_type)
| where EventType == 'INJECTION_BLOCKED'
| project TimeGenerated, EventType"""

    # KQL for credential exposure
    # Triggers on ANY credential exposure - this is always critical
    credential_query = """AppTraces
| where Properties has 'custom_dimensions'
| extend CustomDims = parse_json(replace_string(replace_string(tostring(parse_json(Properties).custom_dimensions), "'", '"'), "None", "null"))
| extend EventType = tostring(CustomDims.event_type)
| where EventType == 'CREDENTIAL_DETECTED'
| project TimeGenerated, EventType"""

    return {
        "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
        "contentVersion": "1.0.0.0",
        "resources": [
            {
                "type": "Microsoft.Insights/scheduledQueryRules",
                "apiVersion": "2023-03-15-preview",
                "name": "mcp-high-attack-volume",
                "location": location,
                "properties": {
                    "displayName": "MCP High Attack Volume Alert",
                    "description": "Triggers when more than 10 attacks detected in 5 minutes",
                    "severity": 2,
                    "enabled": True,
                    "evaluationFrequency": "PT5M",
                    "windowSize": "PT5M",
                    "scopes": [workspace_id],
                    "criteria": {
                        "allOf": [{
                            "query": high_attack_query,
                            "timeAggregation": "Count",
                            "operator": "GreaterThan",
                            "threshold": 10,
                            "failingPeriods": {
                                "numberOfEvaluationPeriods": 1,
                                "minFailingPeriodsToAlert": 1
                            }
                        }]
                    },
                    "actions": {
                        "actionGroups": [action_group_id]
                    }
                }
            },
            {
                "type": "Microsoft.Insights/scheduledQueryRules",
                "apiVersion": "2023-03-15-preview",
                "name": "mcp-credential-exposure",
                "location": location,
                "properties": {
                    "displayName": "MCP Credential Exposure Alert",
                    "description": "Triggers on any credential exposure detection - Severity 1 (Critical)",
                    "severity": 1,
                    "enabled": True,
                    "evaluationFrequency": "PT5M",
                    "windowSize": "PT5M",
                    "scopes": [workspace_id],
                    "criteria": {
                        "allOf": [{
                            "query": credential_query,
                            "timeAggregation": "Count",
                            "operator": "GreaterThan",
                            "threshold": 0,
                            "failingPeriods": {
                                "numberOfEvaluationPeriods": 1,
                                "minFailingPeriodsToAlert": 1
                            }
                        }]
                    },
                    "actions": {
                        "actionGroups": [action_group_id]
                    }
                }
            }
        ]
    }


if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("Usage: create-alert-template.py <workspace_id> <action_group_id> <location>", file=sys.stderr)
        sys.exit(1)
    
    workspace_id = sys.argv[1]
    action_group_id = sys.argv[2]
    location = sys.argv[3]
    
    template = create_template(workspace_id, action_group_id, location)
    print(json.dumps(template, indent=2))
