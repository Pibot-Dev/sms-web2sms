#!/usr/bin/env bash
# Check SMS delivery status via web2sms.ro SOAP API
# Usage: check-status.sh <message_id>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Source .env if it exists, otherwise use env vars
[ -f "$SCRIPT_DIR/.env" ] && source "$SCRIPT_DIR/.env"

MESSAGE_ID="${1:?Usage: check-status.sh <message_id>}"

SOAP_URL="https://www.web2sms.ro/api"

# Build SOAP envelope
SOAP_BODY="<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<soapenv:Envelope xmlns:soapenv=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:web=\"https://www.web2sms.ro/api\">
  <soapenv:Header/>
  <soapenv:Body>
    <web:checkStatus>
      <web:apiKey>${WEB2SMS_API_KEY}</web:apiKey>
      <web:secret>${WEB2SMS_SECRET}</web:secret>
      <web:messageId>${MESSAGE_ID}</web:messageId>
    </web:checkStatus>
  </soapenv:Body>
</soapenv:Envelope>"

RESPONSE=$(curl -s -X POST "$SOAP_URL" \
  -H "Content-Type: text/xml; charset=utf-8" \
  -H "SOAPAction: checkStatus" \
  -d "$SOAP_BODY")

# Parse SOAP response with python3
python3 -c "
import re, sys

response = '''${RESPONSE}'''

# Extract status code
status_match = re.search(r'<status[^>]*>(.*?)</status>', response, re.DOTALL)
cost_match = re.search(r'<cost[^>]*>(.*?)</cost>', response, re.DOTALL)
details_match = re.search(r'<statusDescription[^>]*>(.*?)</statusDescription>', response, re.DOTALL)

if not status_match and not details_match:
    # Try alternative tag names
    status_match = re.search(r'<return[^>]*>(.*?)</return>', response, re.DOTALL)

if status_match:
    status = status_match.group(1).strip()
    cost = cost_match.group(1).strip() if cost_match else 'N/A'
    details = details_match.group(1).strip() if details_match else 'N/A'
    print(f'Message ID: ${MESSAGE_ID}')
    print(f'Status: {status}')
    print(f'Details: {details}')
    print(f'Cost: {cost}')
else:
    print(f'Could not parse response for message ${MESSAGE_ID}', file=sys.stderr)
    print(f'Raw response: {response}', file=sys.stderr)
    sys.exit(1)
"
