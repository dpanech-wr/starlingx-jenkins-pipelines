#!/bin/bash

set -e
source $(dirname "$0")/../lib/job_utils.sh

load_build_env

#VERBOSE_ARG="--verbose"

if [[ -d "$BUILD_HOME/workspace/std/build-helm" ]] ; then
    mkdir -p "$BUILD_OUTPUT_HOME"
    my_user="$(id -u)"
    my_group="$(id -g)"
    safe_copy_dir $DRY_RUN_ARG $VERBOSE_ARG --chown $my_user:$my_group \
        "$BUILD_HOME/workspace/std/build-helm" \
        "$BUILD_OUTPUT_HOME/workspace/std/"
fi
