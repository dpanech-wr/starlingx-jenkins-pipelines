#!/bin/bash

set -e
source $(dirname "$0")/../lib/job_utils.sh

require_env BUILD_STREAM

load_build_env

#VERBOSE_ARG="--verbose"

mkdir -p "$BUILD_OUTPUT_HOME"

if [[ -d "$BUILD_HOME/$WORKSPACE_ROOT_SUBDIR/std/build-images" ]] ; then
    mkdir -p "$BUILD_OUTPUT_HOME/$WORKSPACE_ROOT_SUBDIR/std"
    ln -sfn "$WORKSPACE_ROOT_SUBDIR" "$BUILD_OUTPUT_HOME/workspace"
    safe_copy_dir $DRY_RUN_ARG $VERBOSE_ARG \
        "$BUILD_HOME/workspace/std/build-images" \
        "$BUILD_OUTPUT_HOME/workspace/std/"
fi


