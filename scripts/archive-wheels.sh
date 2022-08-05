#!/bin/bash

set -e
source $(dirname "$0")/lib/job_utils.sh

require_env BUILD_STREAM

load_build_env

#VERBOSE_ARG="--verbose"

mkdir -p "$BUILD_OUTPUT_HOME"

src_dir="$BUILD_HOME/workspace/std/build-wheels-$DOCKER_BASE_OS-$BUILD_STREAM"
dst_dir="$BUILD_OUTPUT_HOME/workspace/std/"
if [[ -d "$src_dir" ]] ; then
    mkdir -p "$dst_dir"
    safe_copy_dir $DRY_RUN_ARG $VERBOSE_ARG "$src_dir" "$dst_dir"
fi
