# /config

This folder should contain the configuration files for Backstage.  These files are copied to /config in the container.

The entrypoint.sh script loads the configuration files in the following order:

- [/config/app-config.yaml](app-config.yaml)
- /config/app-config.*.yaml
- /data/config/app-config.*.yaml (in persistent volume)

Environment variables APP_CONFIG_* can be used to override these configurations.

