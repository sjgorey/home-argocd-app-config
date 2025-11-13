# Finance Exporter

A Prometheus exporter that monitors stock prices and financial metrics from Yahoo Finance.

## Overview

This application exports financial metrics for various stocks to Prometheus, including:
- Current stock price
- Opening price, high, low
- Volume
- Market capitalization
- Daily change percentage

## Monitored Symbols

The symbols are configured via ConfigMap and can be easily updated without rebuilding the container:

Default symbols:
- AAPL, GOOGL, MSFT, TSLA
- SPY, QQQ, NVDA, AMD
- AMZN, META, WEX, F
- GE, BAC, C, JPM

To update the symbols, edit the `SYMBOLS` key in the ConfigMap:

```bash
kubectl edit configmap finance-exporter-config -n finance-exporter
```

Or update the `00-configmap.yaml` file and let ArgoCD sync the changes.

## Features

- Smart scheduling: Only updates during market hours (9:30 AM - 4:00 PM ET, weekdays)
- Automatic market hours detection with timezone handling
- Sleep mode when markets are closed
- Prometheus metrics export on configurable port (default: 8080)
- Configurable stock symbols via Kubernetes ConfigMap
- Configurable update interval via environment variables

## Configuration

The application is configured using environment variables populated from a Kubernetes ConfigMap:

- **SYMBOLS**: Comma-separated list of stock symbols to monitor
- **UPDATE_INTERVAL**: Update frequency in seconds (default: 30)
- **METRICS_PORT**: Port for Prometheus metrics (default: 8080)
- **TZ**: Timezone for market hours calculation (set to "America/New_York")

## Deployment

The application is deployed using ArgoCD with the following components:

- **ConfigMap**: Configuration for symbols, update interval, and metrics port
- **Namespace**: `finance-exporter`
- **Deployment**: Single replica with resource limits
- **Service**: ClusterIP service exposing port 8080
- **ServiceMonitor**: Prometheus service discovery
- **Ingress**: Optional external access with TLS

## Metrics Endpoint

- **URL**: `http://finance-exporter:8080/metrics`
- **External**: `https://finance-exporter.local.sgorey.dev/metrics` (if ingress is enabled)

## Container Image

The application uses the container image built from the Dockerfile in the finance-exporter project:
- **Image**: `sjgorey/finance-exporter:latest`

## Build Instructions

To build and push the container image:

```bash
cd /home/sgorey/projects/openbb-stack/finance-exporter
docker build -t sjgorey/finance-exporter:latest .
docker push sjgorey/finance-exporter:latest
```

## Environment Variables

- **TZ**: Set to "America/New_York" for proper market hours calculation

## Security

- Runs as non-root user (1000:1000)
- No privileged escalation
- Drops all Linux capabilities
- Optional basic auth on ingress endpoint

## Prometheus Integration

The ServiceMonitor is configured to be discovered by Prometheus with the label `release: prometheus`. Metrics are scraped every 30 seconds during market hours.

## Notes

- The application automatically sleeps when markets are closed to reduce API calls
- Updates every 30 seconds during market hours
- Includes health checks for liveness and readiness probes