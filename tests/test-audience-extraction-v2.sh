#!/bin/bash

echo "Testing audience extraction with padding fix..."
echo ""

echo "1. Creating token:"
TOKEN=$(oc create token default --duration=10m 2>&1)
if [ $? -eq 0 ]; then
    echo "✓ Token created"
else
    echo "✗ Failed"
    exit 1
fi
echo ""

echo "2. Extracting payload:"
PAYLOAD=$(echo "$TOKEN" | cut -d. -f2)
echo "Payload length: ${#PAYLOAD}"
echo ""

echo "3. Adding base64 padding if needed:"
# Base64 strings should be divisible by 4, add padding if not
while [ $((${#PAYLOAD} % 4)) -ne 0 ]; do
    PAYLOAD="${PAYLOAD}="
done
echo "Padded payload length: ${#PAYLOAD}"
echo ""

echo "4. Decoding with padding:"
DECODED=$(echo "$PAYLOAD" | base64 -d 2>/dev/null)
echo "Decoded length: ${#DECODED} characters"
echo ""
echo "Full decoded JSON:"
echo "$DECODED"
echo ""

echo "5. Extracting audience with jq:"
AUD=$(echo "$DECODED" | jq -r '.aud[0]' 2>/dev/null)
if [ -n "$AUD" ]; then
    echo "✓ SUCCESS! Audience: $AUD"
else
    echo "✗ Failed to extract audience"
    echo ""
    echo "Trying to extract manually with grep/sed:"
    AUD=$(echo "$DECODED" | grep -o '"aud":\["[^"]*"' | sed 's/"aud":\["\([^"]*\)"/\1/')
    if [ -n "$AUD" ]; then
        echo "✓ Manual extraction worked: $AUD"
    else
        echo "✗ Manual extraction also failed"
    fi
fi
echo ""

echo "Complete!"

