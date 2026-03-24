#!/usr/bin/env bash
# send-sms.sh — Send SMS via web2sms.ro API
# Usage: send-sms.sh <recipient> <message>

set -euo pipefail

RECIPIENT="${1:?Usage: send-sms.sh <recipient> <message>}"
MESSAGE="${2:?Usage: send-sms.sh <recipient> <message>}"

# Load credentials from env file
ENV_FILE="$(dirname "$0")/../.env"
if [[ -f "$ENV_FILE" ]]; then
  # Source .env if exists
  source "$ENV_FILE"
fi

API_KEY="${WEB2SMS_API_KEY:?WEB2SMS_API_KEY not set}"
SECRET="${WEB2SMS_SECRET:?WEB2SMS_SECRET not set}"
SENDER="${WEB2SMS_SENDER:-}"

NONCE="$(date +%s)"
METHOD="POST"
URL="/prepaid/message"
VISIBLE_MESSAGE=""
SCHEDULE_DATE=""
VALIDITY_DATE=""
CALLBACK_URL=""

# Calculate SHA-512 signature
STRING_TO_HASH="${API_KEY}${NONCE}${METHOD}${URL}${SENDER}${RECIPIENT}${MESSAGE}${VISIBLE_MESSAGE}${SCHEDULE_DATE}${VALIDITY_DATE}${CALLBACK_URL}${SECRET}"
SIGNATURE=$(echo -n "$STRING_TO_HASH" | sha512sum | awk '{print $1}')

# Build JSON payload (no jq dependency)
json_escape() { printf '%s' "$1" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()), end="")'; }
PAYLOAD=$(cat <<EOF
{"apiKey":$(json_escape "$API_KEY"),"sender":$(json_escape "$SENDER"),"recipient":$(json_escape "$RECIPIENT"),"message":$(json_escape "$MESSAGE"),"scheduleDatetime":"$SCHEDULE_DATE","validityDatetime":"$VALIDITY_DATE","callbackUrl":"$CALLBACK_URL","userData":"","visibleMessage":"$VISIBLE_MESSAGE","nonce":"$NONCE"}
EOF
)

# Send request
RESPONSE=$(curl -s -w "\n%{http_code}" \
  -X POST "https://www.web2sms.ro/prepaid/message" \
  -u "${API_KEY}:${SIGNATURE}" \
  -H "Content-Type: application/json" \
  -H "Accept-Encoding: gzip, deflate" \
  --compressed \
  -d "$PAYLOAD")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

echo "HTTP Status: $HTTP_CODE"
echo "Response: $BODY"

if [[ "$HTTP_CODE" == "201" ]]; then
  ERROR_CODE=$(echo "$BODY" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('error',{}).get('code',''))" 2>/dev/null || echo "")
  if [[ "$ERROR_CODE" == "0" ]]; then
    SMS_ID=$(echo "$BODY" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('id','unknown'))" 2>/dev/null || echo "unknown")
    echo "SMS trimis cu succes! ID: $SMS_ID"
    exit 0
  fi
fi

echo "Eroare la trimitere SMS"
exit 1
