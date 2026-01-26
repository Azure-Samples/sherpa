#!/usr/bin/env python3
"""
Create ARM template for MCP Security Dashboard workbook.
Called by 3.1-deploy-workbook.sh with environment variables.
"""
import json
import os
import sys

def main():
    workspace_id = os.environ.get("WORKSPACE_ID")
    workbook_guid = os.environ.get("WORKBOOK_GUID")
    location = os.environ.get("LOCATION")
    output_file = os.environ.get("OUTPUT_FILE", "/tmp/mcp-workbook-template.json")
    
    if not all([workspace_id, workbook_guid, location]):
        print("Error: WORKSPACE_ID, WORKBOOK_GUID, and LOCATION environment variables required", file=sys.stderr)
        return 1
    
    # KQL query helper - custom dimensions parsing
    # Azure Monitor OpenTelemetry for Python stores custom dimensions as a Python dict string
    # (with single quotes and None). Properties itself is also a JSON string that must be parsed first.
    custom_dims_parse = '''parse_json(replace_string(replace_string(tostring(parse_json(Properties).custom_dimensions), "'", "\\""), "None", "null"))'''
    
    # Workbook content with KQL queries
    workbook_content = {
        "version": "Notebook/1.0",
        "items": [
            {
                "type": 1,
                "content": {"json": "# MCP Security Dashboard\n\nThis workbook provides visibility into MCP traffic and security events.\n\n**Pattern:** hidden → visible → **actionable**"},
                "name": "header"
            },
            {
                "type": 3,
                "content": {
                    "version": "KqlItem/1.0",
                    "query": 'ApiManagementGatewayLogs\n| where TimeGenerated > ago(24h)\n| where ApiId contains "mcp" or ApiId contains "sherpa"\n| summarize Requests=count() by bin(TimeGenerated, 1h)\n| order by TimeGenerated asc',
                    "size": 0,
                    "title": "MCP Request Volume (24h)",
                    "timeContext": {"durationMs": 86400000},
                    "queryType": 0,
                    "visualization": "areachart"
                },
                "name": "request-volume"
            },
            {
                "type": 3,
                "content": {
                    "version": "KqlItem/1.0",
                    "query": f'''AppTraces
| where TimeGenerated > ago(24h)
| where Properties has "event_type"
| extend CustomDims = {custom_dims_parse}
| extend EventType = tostring(CustomDims.event_type), InjectionType = tostring(CustomDims.injection_type)
| where EventType == "INJECTION_BLOCKED"
| summarize Attacks=count() by InjectionType
| order by Attacks desc''',
                    "size": 0,
                    "title": "Attacks by Injection Type",
                    "timeContext": {"durationMs": 86400000},
                    "queryType": 0,
                    "visualization": "piechart"
                },
                "name": "attacks-by-type"
            },
            {
                "type": 3,
                "content": {
                    "version": "KqlItem/1.0",
                    "query": f'''AppTraces
| where TimeGenerated > ago(24h)
| where Properties has "event_type"
| extend CustomDims = {custom_dims_parse}
| extend EventType = tostring(CustomDims.event_type), ToolName = tostring(CustomDims.tool_name)
| where EventType == "INJECTION_BLOCKED" and isnotempty(ToolName)
| summarize Attacks=count() by ToolName
| order by Attacks desc
| limit 10''',
                    "size": 0,
                    "title": "Top Targeted Tools",
                    "timeContext": {"durationMs": 86400000},
                    "queryType": 0,
                    "visualization": "barchart"
                },
                "name": "top-tools"
            },
            {
                "type": 3,
                "content": {
                    "version": "KqlItem/1.0",
                    "query": 'ApiManagementGatewayLogs\n| where TimeGenerated > ago(24h)\n| where ApiId contains "mcp" or ApiId contains "sherpa"\n| where ResponseCode >= 400\n| summarize Errors=count() by CallerIpAddress\n| order by Errors desc\n| limit 10',
                    "size": 0,
                    "title": "Top Error Sources (by IP)",
                    "timeContext": {"durationMs": 86400000},
                    "queryType": 0,
                    "visualization": "table"
                },
                "name": "error-sources"
            },
            {
                "type": 3,
                "content": {
                    "version": "KqlItem/1.0",
                    "query": f'''AppTraces
| where TimeGenerated > ago(4h)
| where Properties has "event_type"
| extend CustomDims = {custom_dims_parse}
| extend EventType = tostring(CustomDims.event_type),
         InjectionType = tostring(CustomDims.injection_type),
         CorrelationId = tostring(CustomDims.correlation_id)
| project TimeGenerated, EventType, InjectionType, CorrelationId
| order by TimeGenerated desc
| limit 50''',
                    "size": 0,
                    "title": "Recent Security Events",
                    "timeContext": {"durationMs": 14400000},
                    "queryType": 0,
                    "visualization": "table"
                },
                "name": "recent-events"
            }
        ],
        "styleSettings": {},
        "$schema": "https://github.com/Microsoft/Application-Insights-Workbooks/blob/master/schema/workbook.json"
    }
    
    # ARM template
    template = {
        "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
        "contentVersion": "1.0.0.0",
        "resources": [
            {
                "type": "Microsoft.Insights/workbooks",
                "apiVersion": "2022-04-01",
                "name": workbook_guid,
                "location": location,
                "kind": "shared",
                "properties": {
                    "displayName": "MCP Security Dashboard",
                    "category": "workbook",
                    "sourceId": workspace_id,
                    "serializedData": json.dumps(workbook_content)
                }
            }
        ]
    }
    
    with open(output_file, "w") as f:
        json.dump(template, f, indent=2)
    
    print(f"Template created: {output_file}")
    return 0

if __name__ == "__main__":
    sys.exit(main())
