#!/bin/bash

# Create persistent data folders
mkdir -p /data/config /data/catalogs

ARGS="--config app-config.yaml"
for i in /data/config/app-config.*.yaml; do
    test -r $i || continue
    ARGS="$ARGS --config $i"
done

set -x
exec node packages/backend $ARGS
