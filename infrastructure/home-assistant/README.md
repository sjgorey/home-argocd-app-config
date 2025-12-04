# Home Assistant Configuration

## Custom Configuration

Home Assistant custom configurations are managed via ConfigMap to ensure they persist even if the PVC is lost.

1. **configmap.yaml** - Contains custom configurations (HTTP reverse proxy, logger, recorder, etc.)
2. **deployment.yaml** - Mounts the ConfigMap to `/config/packages/custom.yaml`

### How it works

The `custom.yaml` configuration is mounted from the ConfigMap into the packages directory, which Home Assistant automatically loads. The current configuration includes:
- Enables `use_x_forwarded_for` to trust the X-Forwarded-For header
- Trusts the Kubernetes pod network CIDRs (10.42.0.0/16 and 10.43.0.0/16)

### Manual setup (if needed)

If you need to recreate this configuration manually after losing the PVC:

1. Add the packages directive to `/config/configuration.yaml`:
```yaml
# Load packages
homeassistant:
  packages: !include_dir_named packages
```

2. The `custom.yaml` file will be automatically mounted from the ConfigMap

3. Restart the deployment:
```bash
kubectl rollout restart deployment home-assistant -n home
```

### Troubleshooting

If you see errors like:
```
ERROR (MainThread) [homeassistant.components.http.forwarded] A request from a reverse proxy was received from 10.42.x.x, but your HTTP integration is not set-up for reverse proxies
```

Check that:
1. The ConfigMap is properly mounted to `/config/packages/custom.yaml`
2. The `configuration.yaml` includes the packages directive
3. The pod has been restarted after making changes

### Adding custom configurations

To add more configurations, edit the `configmap.yaml` file and add your settings under the `custom.yaml` key. Examples:

```yaml
data:
  custom.yaml: |
    # HTTP Configuration for reverse proxy
    http:
      use_x_forwarded_for: true
      trusted_proxies:
        - 10.42.0.0/16
        - 10.43.0.0/16
    
    # Logger configuration
    logger:
      default: info
      logs:
        homeassistant.components.mqtt: debug
    
    # Recorder configuration
    recorder:
      purge_keep_days: 7
      db_url: !secret db_url
```

After editing, the pod will automatically restart and pick up the new configuration.
