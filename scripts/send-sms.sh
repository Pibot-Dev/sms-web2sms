#!/usr/bin/env bash
# send-sms.sh — Send SMS via web2sms.ro API
# Usage: send-sms.sh [--force-gsm7] <recipient> <message>
#
# Options:
#   --force-gsm7  Transliterate message to GSM-7 charset before sending
#                 (strips diacritics and non-GSM characters)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/error-codes.sh"

# Parse flags
FORCE_GSM7=0
while [[ "${1:-}" == --* ]]; do
  case "$1" in
    --force-gsm7) FORCE_GSM7=1; shift ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

RECIPIENT="${1:?Usage: send-sms.sh [--force-gsm7] <recipient> <message>}"
MESSAGE="${2:?Usage: send-sms.sh [--force-gsm7] <recipient> <message>}"

# GSM-7 transliteration via Python
if [[ "$FORCE_GSM7" -eq 1 ]]; then
  MESSAGE=$(python3 -c "
import sys

GSM7_BASIC = set(
    '@£\$¥èéùìòÇØøÅåΔ_ΦΓΛΩΠΨΣΘΞ Æ æß É'
    ' !\"#¤%&\\'()*+,-./'
    '0123456789:;<=>?¡'
    'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    'ÄÖÑܧ¿'
    'abcdefghijklmnopqrstuvwxyz'
    'äöñüà\n\r'
)
GSM7_EXT = set('^{}[]~|€\\\\')
GSM7 = GSM7_BASIC | GSM7_EXT

TRANSLIT = {
    'ă':'a','Ă':'A','î':'i','Î':'I','â':'a','Â':'A',
    'ș':'s','Ș':'S','ț':'t','Ț':'T',
    'ş':'s','Ş':'S','ţ':'t','Ţ':'T',
    'ê':'e','ë':'e','û':'u','ú':'u',
    'ï':'i','í':'i','ô':'o','ó':'o','õ':'o',
    'á':'a','ã':'a','ç':'c','ý':'y','ÿ':'y',
    'ń':'n','ś':'s','š':'s','ź':'z','ž':'z','ż':'z',
    'ć':'c','č':'c','ř':'r','ď':'d','ð':'d',
    'ľ':'l','ł':'l','ě':'e','ů':'u','ğ':'g','ı':'i',
    'Ê':'E','Ë':'E','Û':'U','Ú':'U','Ï':'I','Í':'I',
    'Ô':'O','Ó':'O','Õ':'O','Á':'A','Ã':'A','Ý':'Y',
    'Ń':'N','Ś':'S','Š':'S','Ź':'Z','Ž':'Z','Ż':'Z',
    'Ć':'C','Č':'C','Ř':'R','Ď':'D','Ð':'D',
    'Ľ':'L','Ł':'L','Ě':'E','Ů':'U','Ğ':'G','İ':'I',
    '\u201c':'\"','\u201d':'\"','\u2018':\"'\",'\u2019':\"'\",
    '\u2014':'-','\u2013':'-','\u2026':'...',
}

text = sys.stdin.read().rstrip('\n')
result = []
for ch in text:
    if ch in GSM7:
        result.append(ch)
    elif ch in TRANSLIT:
        result.append(TRANSLIT[ch])
    # else: strip
print(''.join(result), end='')
" <<< "$MESSAGE")
fi

# Load credentials from env file
ENV_FILE="$SCRIPT_DIR/../.env"
[ -f "$ENV_FILE" ] && source "$ENV_FILE"

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

# Parse response
ERROR_CODE=$(echo "$BODY" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('error',{}).get('code',''))" 2>/dev/null || echo "")
ERROR_CODE="${ERROR_CODE:-$HTTP_CODE}"
ERROR_MSG=$(echo "$BODY" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('error',{}).get('message',''))" 2>/dev/null || echo "parse error")

if [[ "$ERROR_CODE" == "0" ]]; then
  SMS_ID=$(echo "$BODY" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('id','unknown'))" 2>/dev/null || echo "unknown")
  echo "✅ SMS sent successfully! ID: $SMS_ID"
  exit 0
else
  ERROR_DESC=$(decode_error "$ERROR_CODE" "$ERROR_MSG")
  echo "❌ SMS failed (HTTP $HTTP_CODE)"
  echo "Error code: $ERROR_CODE"
  echo "Error: $ERROR_DESC"
  echo "Raw: $ERROR_MSG"
  exit 1
fi
