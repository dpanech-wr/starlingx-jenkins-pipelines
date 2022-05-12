#!/bin/bash

set -e
source $(dirname "$0")/../lib/job_utils.sh

require_env BUILD_STATUS

load_build_env

if $DRY_RUN ; then
    bail "DRY_RUN=true, bailing out..."
fi

touch "$BUILD_OUTPUT_HOME/FAIL"

ARCHIVE_ROOT=$(dirname "$BUILD_OUTPUT_HOME")

if [[ "$BUILD_STATUS" == "success" ]] ; then
    ARCHIVE_ROOT=$(dirname "$BUILD_OUTPUT_HOME")
    link_target=$(basename "$BUILD_OUTPUT_HOME")
    cp "$BUILD_OUTPUT_HOME/LAST_COMMITS" "$ARCHIVE_ROOT/"
    ln -sfn "$link_target" "$ARCHIVE_ROOT/latest_build"

    if "$BUILD_DOCKER_IMAGES"  ; then
        cp "$BUILD_OUTPUT_HOME/LAST_COMMITS" "$ARCHIVE_ROOT/LAST_COMMITS_IMG_STABLE"
        ln -sfn "$link_target" "$ARCHIVE_ROOT/latest_docker_image_build"
    fi
    rm -f "$BUILD_OUTPUT_HOME/FAIL"
    touch "$BUILD_OUTPUT_HOME/SUCCESS"

    mkdir -p "$PUBLISH_ROOT"
    if ! same_path "$PUBLISH_ROOT" "$ARCHIVE_ROOT" ; then
        link_target="${PUBLISH_ROOT}/$PUBLISH_TIMESTAMP"
        if [[ -d "$link_target" ]] ; then
            ln -sfn "$PUBLISH_TIMESTAMP" "$PUBLISH_ROOT/latest_build"
        fi
    fi

fi
