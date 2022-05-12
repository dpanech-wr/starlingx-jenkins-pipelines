#!/bin/bash

set -e
source $(dirname "$0")/../lib/job_utils.sh

load_build_env

#VERBOSE_ARG="--verbose"

mkdir -p "$BUILD_OUTPUT_HOME"
safe_copy_dir $DRY_RUN_ARG $VERBOSE_ARG \
        --exclude /aptly \
        --exclude /localdisk/channel/\*\* \
        --exclude /localdisk/designer \
        --exclude /mirrors \
        --exclude /localdisk/lat \
    "$BUILD_HOME/" "$BUILD_OUTPUT_HOME/"

# localdist/loadbuild/$USER
mkdir -p "$BUILD_OUTPUT_HOME/$(dirname "$REPO_ROOT_SUBDIR")"

# localdisk/designer/$USER/$PROJECT => $BUILD_HOME/...
ln -sfn "$BUILD_HOME/$REPO_ROOT_SUBDIR" "$BUILD_OUTPUT_HOME/$REPO_ROOT_SUBDIR"

# repo => localdisk/designer/$USER/$PROJECT
ln -sfn "$REPO_ROOT_SUBDIR"       "$BUILD_OUTPUT_HOME/repo"

# workspace => localdist/loadbuild/$USER/PROJECT
ln -sfn "$WORKSPACE_ROOT_SUBDIR"  "$BUILD_OUTPUT_HOME/workspace"

# aptly => $BUILD_HOME/...
ln -sfn "$BUILD_HOME/aptly" "$BUILD_OUTPUT_HOME/aptly"

