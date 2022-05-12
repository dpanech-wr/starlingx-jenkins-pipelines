#!/bin/bash

set -e
source $(dirname "$0")/../lib/job_utils.sh

require_env BUILD_HOME
require_env BUILD_ISO
require_env BUILD_RT

load_build_env

$BUILD_ISO || bail "BUILD_ISO=false, bailing out"

notice "building STD ISO"
stx_docker_cmd $DRY_RUN_ARG "build-image --std"
if ! $DRY_RUN ; then
    ln -sfn lat/std/deploy "$BUILD_HOME/localdisk/deploy"
fi

if $BUILD_RT ; then
    notice "building RT ISO"
    stx_docker_cmd $DRY_RUN_ARG "build-image --rt"
fi
