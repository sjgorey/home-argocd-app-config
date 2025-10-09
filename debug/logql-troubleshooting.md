# LogQL Query Troubleshooting Guide

## Common LogQL Syntax Errors and Fixes

### Basic Query Syntax
```logql
# ✅ CORRECT - Basic label selector
{pod="test-logger"}

# ✅ CORRECT - Multiple labels
{pod="test-logger", namespace="default"}

# ✅ CORRECT - Regex matching
{pod=~".*logger.*"}

# ❌ INCORRECT - Missing quotes
{pod=test-logger}

# ❌ INCORRECT - Wrong operator
{pod=="test-logger"}
```

### Log Filtering
```logql
# ✅ CORRECT - Text filtering
{pod="test-logger"} |= "ERROR"

# ✅ CORRECT - Multiple filters
{pod="test-logger"} |= "ERROR" |~ "iteration"

# ✅ CORRECT - Exclude logs
{pod="test-logger"} != "DEBUG"

# ❌ INCORRECT - Missing quotes around search text
{pod="test-logger"} |= ERROR

# ❌ INCORRECT - Wrong filter operator
{pod="test-logger"} == "ERROR"
```

## Verified Working Queries for Test Pods

### Simple Queries
```logql
# All logs from test-logger pod
{pod="test-logger"}

# All logs from multi-app-logger pod
{pod="multi-app-logger"}

# All logger pods
{pod=~".*logger.*"}

# Logs from default namespace
{namespace="default"}
```

### Filtered Queries
```logql
# Only ERROR messages
{pod=~".*logger.*"} |= "ERROR"

# Only WARNING messages
{pod=~".*logger.*"} |= "WARN"

# Only INFO messages
{pod=~".*logger.*"} |= "INFO"

# Webapp container only
{pod="multi-app-logger", container="webapp"}

# Database container only
{pod="multi-app-logger", container="database"}

# HTTP 500 errors
{container="webapp"} |= "500"

# Database slow queries
{container="database"} |= "Slow query"
```

### Metric Queries (for dashboards)
```logql
# Count of logs per minute
count_over_time({pod=~".*logger.*"}[1m])

# Rate of logs per second
rate({pod=~".*logger.*"}[5m])

# Count of ERROR logs per minute
count_over_time({pod=~".*logger.*"} |= "ERROR"[1m])

# Sum of logs by pod
sum by (pod) (count_over_time({pod=~".*logger.*"}[1m]))
```

## Common Issues and Solutions

### 1. "unexpected IDENTIFIER" Error
**Cause**: Usually missing quotes around label values or search text
**Fix**: Always use quotes around values
```logql
# ❌ Wrong
{pod=test-logger}

# ✅ Correct  
{pod="test-logger"}
```

### 2. "parse error" with regex
**Cause**: Invalid regex syntax
**Fix**: Use proper regex operators
```logql
# ❌ Wrong
{pod=~.*logger.*}

# ✅ Correct
{pod=~".*logger.*"}
```

### 3. "no data" results
**Cause**: Query might be correct but no matching logs
**Fix**: Check with broader query first
```logql
# Start broad
{namespace="default"}

# Then narrow down
{namespace="default", pod=~".*logger.*"}
```

## Testing Your Queries

### Step 1: Start Simple
```logql
{namespace="default"}
```

### Step 2: Add Pod Filter
```logql
{namespace="default", pod="test-logger"}
```

### Step 3: Add Log Level Filter
```logql
{namespace="default", pod="test-logger"} |= "INFO"
```

## Quick Verification Commands

Run these in your terminal to verify logs are being ingested:
```bash
# Check if pods are running
kubectl get pods -n default | grep logger

# Check recent logs via kubectl
kubectl logs test-logger -n default --tail=5

# Check if Loki is receiving logs (requires port-forward)
kubectl port-forward -n logging svc/loki 3100:3100 &
curl -s "http://localhost:3100/loki/api/v1/labels"
```