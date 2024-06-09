#!/bin/bash

# Create persistent data folders
mkdir -p /data/config /data/catalogs

# Construct ARGS to load all config files
ARGS="--config /config/app-config.yaml"
for i in /config/app-config.*.yaml /data/config/app-config.*.yaml; do
    test -r $i || continue
    ARGS="$ARGS --config $i"
done

set -x
exec node packages/backend $ARGS
