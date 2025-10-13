#!/bin/bash
set -e

# IndexNow submission script for Bing Webmaster Tools
# Automatically submits all URLs from sitemap to IndexNow API

INDEXNOW_KEY="9968e047f38847398e3c05323efbdd7a"
SITE_URL="https://fatihkoc.net"
SITEMAP_URL="${SITE_URL}/sitemap.xml"
INDEXNOW_ENDPOINT="https://api.indexnow.org/indexnow"

echo "🔐 Verifying IndexNow key at ${SITE_URL}/${INDEXNOW_KEY}.txt..."

# Ensure the verification key is live and matches before submitting (avoid locale issues)
KEY_URL="${SITE_URL}/${INDEXNOW_KEY}.txt"
KEY_HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$KEY_URL" || true)
KEY_BODY=$(curl -sL "$KEY_URL" || true)

if [ "$KEY_HTTP_CODE" != "200" ] || [ "$KEY_BODY" != "$INDEXNOW_KEY" ]; then
    echo "❌ Key verification failed. Expected ${INDEXNOW_KEY} at ${KEY_URL}"
    echo "   Got HTTP ${KEY_HTTP_CODE} with body: '${KEY_BODY}'"
    echo "   Deploy the new key file first, then rerun this script."
    echo "   Example commands:"
    echo "     hugo --source site --minify"
    echo "     hugo --source site deploy"
    exit 1
fi

echo "🔍 Fetching sitemap from ${SITEMAP_URL}..."

# Download and parse sitemap to extract all URLs
# Handle both gzipped and minified XML sitemaps
# Use grep with basic regex for macOS compatibility
URLS=$(curl -s --compressed "${SITEMAP_URL}" | \
  grep -o '<loc>[^<]*</loc>' | \
  sed 's:<loc>::g;s:</loc>::g' || true)

if [ -z "$URLS" ]; then
    echo "❌ No URLs found in sitemap"
    exit 1
fi

# Count URLs
URL_COUNT=$(echo "$URLS" | wc -l)
echo "📊 Found ${URL_COUNT} URLs to submit"

# Create JSON payload
# IndexNow accepts batch submissions with urlList
JSON_PAYLOAD=$(cat <<EOF
{
  "host": "fatihkoc.net",
  "key": "${INDEXNOW_KEY}",
  "keyLocation": "${SITE_URL}/${INDEXNOW_KEY}.txt",
  "urlList": [
$(echo "$URLS" | sed 's/^/    "/;s/$/",/' | sed '$ s/,$//')
  ]
}
EOF
)

echo "📤 Submitting URLs to IndexNow..."

# Submit to IndexNow API
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${INDEXNOW_ENDPOINT}" \
  -H "Content-Type: application/json; charset=utf-8" \
  -d "${JSON_PAYLOAD}")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$RESPONSE" | sed '$d')

# Check response
if [ "$HTTP_CODE" -eq 200 ]; then
    echo "✅ Successfully submitted ${URL_COUNT} URLs to IndexNow"
    echo "   Status: HTTP ${HTTP_CODE}"
elif [ "$HTTP_CODE" -eq 202 ]; then
    echo "✅ URLs accepted for processing by IndexNow"
    echo "   Status: HTTP ${HTTP_CODE}"
else
    echo "⚠️  IndexNow returned status: HTTP ${HTTP_CODE}"
    if [ -n "$RESPONSE_BODY" ]; then
        echo "   Response: ${RESPONSE_BODY}"
    fi
    # Don't fail the build for IndexNow errors
    echo "   (Continuing deployment despite IndexNow error)"
fi

echo "✨ IndexNow submission complete"

