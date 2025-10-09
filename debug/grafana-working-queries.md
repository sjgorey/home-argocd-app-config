# Corrected LogQL Queries for Grafana

## Issue Identified
Your Loki logs use `app` labels instead of `pod` labels. Use these corrected queries in Grafana:

## ✅ WORKING QUERIES FOR GRAFANA

### Basic Queries
```logql
# All logs from test-logger
{app="test-logger"}

# All logs from multi-app-logger  
{app="multi-app-logger"}

# All logs from both test apps
{app=~"test-logger|multi-app-logger"}

# All logs from default namespace
{namespace="default"}
```

### Container-Specific Queries
```logql
# Webapp container logs only
{app="multi-app-logger", container="webapp"}

# Database container logs only  
{app="multi-app-logger", container="database"}

# Simple logger container
{app="test-logger", container="logger"}
```

### Filtered Queries
```logql
# All ERROR messages from test apps
{app=~"test-logger|multi-app-logger"} |= "ERROR"

# All WARNING messages
{app=~"test-logger|multi-app-logger"} |= "WARN"

# HTTP 500 errors from webapp
{app="multi-app-logger", container="webapp"} |= "500"

# Database slow queries
{app="multi-app-logger", container="database"} |= "Slow query"

# Database connection errors
{app="multi-app-logger", container="database"} |= "Connection timeout"
```

### Metric Queries (for Dashboards)
```logql
# Count of logs per minute
count_over_time({app=~"test-logger|multi-app-logger"}[1m])

# Rate of ERROR logs
rate({app=~"test-logger|multi-app-logger"} |= "ERROR"[5m])

# Count by container
sum by (container) (count_over_time({app="multi-app-logger"}[1m]))

# Error rate percentage
100 * (
  rate({app=~"test-logger|multi-app-logger"} |= "ERROR"[5m]) / 
  rate({app=~"test-logger|multi-app-logger"}[5m])
)
```

## Testing in Grafana

### Step 1: Start with this simple query
```logql
{namespace="default"}
```

### Step 2: Narrow down to your test apps
```logql
{app="test-logger"}
```

### Step 3: Add log filtering
```logql
{app="test-logger"} |= "INFO"
```

## Available Labels in Your Loki
- `app` (test-logger, multi-app-logger, etc.)
- `container` (logger, webapp, database)
- `namespace` (default, logging, etc.)
- `node` (your node names)
- `job` (fluent-bit)
- `instance` (same as app usually)

## Common LogQL Syntax Reminders
- Always use quotes: `{app="test-logger"}` not `{app=test-logger}`
- Use `|=` for "contains": `{app="test-logger"} |= "ERROR"`
- Use `|~` for regex: `{app="test-logger"} |~ "ERROR|WARN"`
- Use `!=` for "does not contain": `{app="test-logger"} != "DEBUG"`
- Use `=~` for label regex: `{app=~"test.*"}`

## Your Original Error Fix
If you were using `{pod="test-logger"}`, change it to `{app="test-logger"}`