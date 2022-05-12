#!/bin/bash

set -e
source $(dirname "$0")/../lib/job_utils.sh

require_env BUILD_RT

load_build_env

#VERBOSE_ARG="--verbose"

$BUILD_PACKAGES || bail "BUILD_PACKAGES=false, skipping build"

if [[ -d "$BUILD_HOME/$WORKSPACE_ROOT_SUBDIR" ]] ; then
    my_user="$(id -u)"
    my_group="$(id -g)"
    mkdir -p "$BUILD_OUTPUT_HOME/$WORKSPACE_ROOT_SUBDIR"
    safe_copy_dir --chown "$my_user:$my_group" $DRY_RUN_ARG $VERBOSE_ARG \
        "$BUILD_HOME/$WORKSPACE_ROOT_SUBDIR/" "$BUILD_OUTPUT_HOME/$WORKSPACE_ROOT_SUBDIR/"
    ln -sfn "$WORKSPACE_ROOT_SUBDIR" "$BUILD_OUTPUT_HOME/workspace"
fi
