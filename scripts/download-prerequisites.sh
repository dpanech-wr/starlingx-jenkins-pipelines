#!/bin/bash

set -e
source $(dirname "$0")/lib/job_utils.sh

require_env BUILD_RT

load_build_env

build_types="std"
if $BUILD_RT ; then
    build_types+=",rt"
fi
stx_docker_cmd $DRY_RUN_ARG "\$MY_REPO/build-tools/stx/downloader -b -s -B $build_types"

