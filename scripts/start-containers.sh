#!/bin/bash

set -e
source $(dirname "$0")/../lib/job_utils.sh

require_env BUILD_HOME
require_env REBUILD_BUILDER_IMAGES
require_env USE_DOCKER_CACHE

set -x
load_build_env

# start containers
if $USE_DOCKER_CACHE ; then
    cache_opts="--cache"
fi
if $REBUILD_BUILDER_IMAGES ; then
    notice "rebuilding & starting containers"
    ./stx-init-env --rebuild $cache_opts
else
    notice "rebuilding containers"
    bash ./stx-init-env $cache_opts
fi

# wait for startup
notice "waiting for containers to startup ($BUILDER_POD_STARTUP_TIMEOUT seconds)"
let deadline="$(date '+%s')+$BUILDER_POD_STARTUP_TIMEOUT"
while [[ "$(stx control status | grep -i running | wc -l)" -lt 5 ]] ; do
    if [[ "$(date '+%s')" -ge $deadline ]] ; then
        die "pods didn't start up after $BUILDER_POD_STARTUP_TIMEOUT second(s)"
    fi
    sleep 10
done
stx control status

# finish setup
stx build prepare

# workaround for: https://bugs.launchpad.net/starlingx/+bug/1981094
stx shell -c 'sudo mkdir -p /var/cache/apt/archives/partial && sudo chmod +rx /var/cache/apt/archives/partial'
