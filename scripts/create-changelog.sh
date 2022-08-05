#!/bin/bash

set -e
source $(dirname "$0")/lib/job_utils.sh
source $(dirname "$0")/lib/changelog_utils.sh

require_env BUILD_HOME
require_env FORCE_BUILD
require_env BUILD_DOCKER_IMAGES_DEV
require_env BUILD_DOCKER_IMAGES_STABLE

load_build_env

rm -f "$BUILD_HOME"/{CHANGELOG*,LAST_COMMITS,NEED_BUILD,NO_BUILD_REQUIRED}

(
    MY_WORKSPACE="$BUILD_HOME"
    MY_REPO_ROOT_DIR="$BUILD_HOME/$REPO_ROOT_SUBDIR"
    set +x
    if need_build ; then
        create_standard_changelogs
    fi
)

