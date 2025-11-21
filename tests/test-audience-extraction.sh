#!/bin/bash

echo "Testing audience extraction..."
echo ""

echo "1. Checking if jq is installed:"
if command -v jq &> /dev/null; then
    echo "✓ jq is installed: $(which jq)"
    jq --version
else
    echo "✗ jq is NOT installed"
    echo ""
    echo "Install with: brew install jq"
    exit 1
fi
echo ""

echo "2. Creating token:"
TOKEN=$(oc create token default --duration=10m 2>&1)
if [ $? -eq 0 ]; then
    echo "✓ Token created successfully"
    echo "Token (first 50 chars): ${TOKEN:0:50}..."
else
    echo "✗ Failed to create token"
    echo "Error: $TOKEN"
    exit 1
fi
echo ""

echo "3. Extracting payload (part 2 of JWT):"
PAYLOAD=$(echo "$TOKEN" | cut -d. -f2)
echo "Payload (base64, first 50 chars): ${PAYLOAD:0:50}..."
echo ""

echo "4. Decoding base64:"
DECODED=$(echo "$PAYLOAD" | base64 -d 2>&1)
if [ $? -eq 0 ]; then
    echo "✓ Base64 decoded successfully"
    echo "Decoded JSON:"
    echo "$DECODED" | jq . 2>/dev/null || echo "$DECODED"
else
    echo "✗ Failed to decode base64"
    echo "Error: $DECODED"
fi
echo ""

echo "5. Extracting audience (method 1 - piped):"
AUD=$(echo "$TOKEN" | cut -d. -f2 | base64 -d 2>/dev/null | jq -r '.aud[0]' 2>/dev/null)
if [ -n "$AUD" ]; then
    echo "✓ Audience extracted: $AUD"
else
    echo "✗ Failed with piped base64 -d"
fi
echo ""

echo "6. Extracting audience (method 2 - variable):"
PAYLOAD=$(echo "$TOKEN" | cut -d. -f2)
DECODED=$(echo "$PAYLOAD" | base64 -d 2>/dev/null)
echo "Decoded length: ${#DECODED} characters"
AUD=$(echo "$DECODED" | jq -r '.aud[0]' 2>/dev/null)
if [ -n "$AUD" ]; then
    echo "✓ Audience extracted: $AUD"
else
    echo "✗ Failed to extract with jq"
    echo ""
    echo "Trying with -D flag..."
    DECODED=$(echo "$PAYLOAD" | base64 -D 2>/dev/null)
    echo "Decoded length: ${#DECODED} characters"
    AUD=$(echo "$DECODED" | jq -r '.aud[0]' 2>/dev/null)
    if [ -n "$AUD" ]; then
        echo "✓ Audience extracted with -D: $AUD"
    else
        echo "✗ Still failed"
        echo ""
        echo "Full decoded output:"
        echo "$DECODED"
    fi
fi
echo ""

echo "Complete!"

