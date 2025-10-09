#!/bin/bash

# Test script to query Loki for our test logger pods
echo "Testing Loki log ingestion for test logger pods..."

# Wait for port-forward to be available
echo "Make sure you have port-forward running: kubectl port-forward -n logging svc/loki 3100:3100"
echo ""

# Query for test-logger pod logs
echo "=== Querying for test-logger pod logs ==="
curl -s "http://localhost:3100/loki/api/v1/query_range" \
  --data-urlencode 'query={pod="test-logger"}' \
  --data-urlencode 'start='"$(date -d '5 minutes ago' -u +%s000000000)" \
  --data-urlencode 'end='"$(date -u +%s000000000)" \
  | jq '.data.result[] | .values[] | .[1]' | head -5

echo ""
echo "=== Querying for multi-app-logger webapp logs ==="
curl -s "http://localhost:3100/loki/api/v1/query_range" \
  --data-urlencode 'query={pod="multi-app-logger", container="webapp"}' \
  --data-urlencode 'start='"$(date -d '5 minutes ago' -u +%s000000000)" \
  --data-urlencode 'end='"$(date -u +%s000000000)" \
  | jq '.data.result[] | .values[] | .[1]' | head -3

echo ""
echo "=== Querying for multi-app-logger database logs ==="
curl -s "http://localhost:3100/loki/api/v1/query_range" \
  --data-urlencode 'query={pod="multi-app-logger", container="database"}' \
  --data-urlencode 'start='"$(date -d '5 minutes ago' -u +%s000000000)" \
  --data-urlencode 'end='"$(date -u +%s000000000)" \
  | jq '.data.result[] | .values[] | .[1]' | head -3

echo ""
echo "=== Querying for ERROR level logs from all test pods ==="
curl -s "http://localhost:3100/loki/api/v1/query_range" \
  --data-urlencode 'query={pod=~".*logger.*"} |= "ERROR"' \
  --data-urlencode 'start='"$(date -d '5 minutes ago' -u +%s000000000)" \
  --data-urlencode 'end='"$(date -u +%s000000000)" \
  | jq '.data.result[] | .values[] | .[1]'