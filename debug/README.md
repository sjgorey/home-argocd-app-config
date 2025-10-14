# Test Logger Pods for Loki/Grafana

This directory contains test pods that generate various log patterns to test the Loki logging stack.

**Note**: Test logger pods are currently disabled (files renamed to `.yaml.disabled`) to avoid cluttering the production cluster. They can be re-enabled by removing the `.disabled` extension if needed for testing.

## Test Pods (Currently Disabled)

### 1. Simple Test Logger (`test-logger-pod.yaml.disabled`)
- **Container**: Single busybox container
- **Log Pattern**: Generates INFO, DEBUG, WARN, and ERROR messages every 30 seconds
- **Features**: 
  - Sequential counter
  - Memory usage information
  - Simulated errors every 5th iteration
  - Pod uptime tracking

### 2. Multi-Application Logger (`multi-app-logger-pod.yaml.disabled`)
- **Containers**: Two containers simulating webapp and database
- **webapp container**: 
  - Simulates HTTP requests (GET, POST, PUT, DELETE)
  - Various endpoints (/api/users, /health, etc.)
  - Status codes: mostly 200, occasional 404/500
  - Response times
- **database container**:
  - Simulates database operations (SELECT, INSERT, UPDATE, DELETE)
  - Different tables (users, orders, products, sessions)
  - Occasional slow query warnings
  - Connection timeout errors

## Deployment (When Enabled)

To re-enable the test loggers, rename the files back to `.yaml` and apply:

```bash
# Re-enable files (if needed)
mv debug/test-logger-pod.yaml.disabled debug/test-logger-pod.yaml
mv debug/multi-app-logger-pod.yaml.disabled debug/multi-app-logger-pod.yaml

# Deploy simple test logger
kubectl apply -f debug/test-logger-pod.yaml

# Deploy multi-app logger
kubectl apply -f debug/multi-app-logger-pod.yaml

# Check pod status
kubectl get pods -n default | grep logger
```

## Monitoring Logs

### Via kubectl
```bash
# View simple logger logs
kubectl logs test-logger -n default

# View webapp logs
kubectl logs multi-app-logger -c webapp -n default

# View database logs
kubectl logs multi-app-logger -c database -n default

# Follow logs in real-time
kubectl logs -f test-logger -n default
```

### Via Loki API (requires port-forward)
```bash
# Start port-forward to Loki
kubectl port-forward -n logging svc/loki 3100:3100 &

# Run test queries
./debug/test-loki-queries.sh
```

### Via Grafana
1. Access Grafana via your ingress or port-forward
2. Go to **Explore** section
3. Select **Loki** as data source
4. Use these example LogQL queries:

```logql
# All logs from test logger pods
{pod=~".*logger.*"}

# Only webapp logs
{pod="multi-app-logger", container="webapp"}

# Only database logs  
{pod="multi-app-logger", container="database"}

# Error messages only
{pod=~".*logger.*"} |= "ERROR"

# Warning messages only
{pod=~".*logger.*"} |= "WARN"

# HTTP 500 errors
{pod="multi-app-logger", container="webapp"} |= "500"

# Slow database queries
{pod="multi-app-logger", container="database"} |= "Slow query"

# All logs from default namespace
{namespace="default"}

# Count of log messages per minute
count_over_time({pod=~".*logger.*"}[1m])

# Rate of ERROR messages
rate({pod=~".*logger.*"} |= "ERROR"[5m])
```

## Log Patterns Generated

### Simple Test Logger
```
[2025-10-09 19:40:12] INFO: Test log message #1 from test-logger pod
[2025-10-09 19:40:12] DEBUG: Current memory usage: MemAvailable: 6450412 kB
[2025-10-09 19:40:12] WARN: This is a warning message for testing purposes
[2025-10-09 19:40:12] ERROR: Simulated error message every 5th iteration (count: 5)
[2025-10-09 19:40:12] INFO: Pod uptime: 278121.15 seconds
```

### Multi-App Logger
```
webapp: [2025-10-09 19:41:35] INFO: POST /api/orders - 200 - 51ms
webapp: [2025-10-09 19:41:35] ERROR: Internal server error on POST /api/orders
database: [2025-10-09 19:41:35] INFO: INSERT on orders completed in 11ms
database: [2025-10-09 19:41:35] WARN: Slow query detected: SELECT on users took 89ms
database: [2025-10-09 19:41:35] ERROR: Connection timeout to database cluster
```

## Cleanup

```bash
# Delete test pods
kubectl delete pod test-logger -n default
kubectl delete pod multi-app-logger -n default

# Delete test files
rm debug/test-logger-pod.yaml
rm debug/multi-app-logger-pod.yaml
rm debug/test-loki-queries.sh
```

## Useful Grafana Dashboards

Consider creating dashboards with panels for:
1. **Log volume over time** - Count of logs per minute/hour
2. **Error rate** - Percentage of ERROR vs total logs
3. **Response time distribution** - From webapp logs
4. **Database operation metrics** - Operation types and timing
5. **Pod health** - Uptime and memory usage from simple logger