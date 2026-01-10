#!/usr/bin/env python3
"""Update the auth-callback policy in APIM."""
import subprocess
import json
import sys

# Read the policy
with open('infra/policies/auth-callback.xml', 'r') as f:
    policy = f.read()

# Get subscription ID
result = subprocess.run(['az', 'account', 'show', '--query', 'id', '-o', 'tsv'], capture_output=True, text=True)
sub_id = result.stdout.strip()

# Build the body
body = {"properties": {"format": "rawxml", "value": policy}}

# Write to temp file
with open('/tmp/body.json', 'w') as f:
    json.dump(body, f)

# Call az rest
uri = f"https://management.azure.com/subscriptions/{sub_id}/resourceGroups/rg-camp2-dev1/providers/Microsoft.ApiManagement/service/apim-rg-camp2-dev1-iggsqsougqeqc/apis/oauth-prm/operations/auth-callback/policies/policy?api-version=2024-05-01"
result = subprocess.run(['az', 'rest', '--method', 'PUT', '--uri', uri, '--body', '@/tmp/body.json'], capture_output=True, text=True)
print(result.stdout)
if result.returncode != 0:
    print(f"Error: {result.stderr}")
    sys.exit(1)
else:
    print("Policy updated!")
