#!/bin/bash

set -e
source $(dirname "$0")/../lib/job_utils.sh

require_env BUILD_HOME
require_env DRY_RUN
require_env USE_DOCKER_CACHE
require_env BUILD_STREAM stable
require_env PUSH_DOCKER_IMAGES
declare_env PUBLISH_ROOT_URL
declare_env DOCKER_IMAGE_BASE

load_build_env

if [[ -n "$DOCKER_IMAGE_BASE" ]] ; then
    bail "DOCKER_IMAGE_BASE is set, bailing out"
fi

base_image_tag="$BUILD_BRANCH-$BUILD_STREAM-$TIMESTAMP"
base_image_latest_tag="$BUILD_BRANCH-$BUILD_STREAM-latest"

declare -a cmd=(
    "./build-stx-base.sh"
    "--os=$DOCKER_BASE_OS"
    "--version=$base_image_tag"
    "--attempts=$DOCKER_BUILD_RETRY_COUNT"
    "--stream=$BUILD_STREAM"
    "--registry=$DOCKER_REGISTRY"
    "--user=$DOCKER_REGISTRY_ORG"
    "--latest"
    "--latest-tag=$base_image_latest_tag"
)

if [[ "$USE_DOCKER_CACHE" == true ]] ; then
    cmd+=("--cache")
fi

if $USE_POD_URLS_IN_DOCKER_IMAGES ; then
    cmd+=("--local")
else
    require_env PUBLISH_ROOT_URL
    cmd+=("--repo 'deb [trusted=yes check-valid-until=0] $PUBLISH_URL/inputs/packages ./'")
    cmd+=("--repo 'deb [trusted=yes check-valid-until=0] $PUBLISH_URL/outputs/std/packages ./'")
fi

# build-stx-base.sh can only push to one repo. We will push to any
# additional repos manually.
if $PUSH_DOCKER_IMAGES ; then
    cmd+=("--push")
fi

# build it
stx_docker_cmd $DRY_RUN_ARG "cd \$MY_REPO/build-tools/build-docker-images && ${cmd[*]}"

# retag and push it to extra registries
if $PUSH_DOCKER_IMAGES ; then
    for reg in $EXTRA_REGISTRY_PREFIX_LIST ; do
        stx_docker_cmd $DRY_RUN_ARG "docker tag $DOCKER_REGISTRY/$DOCKER_REGISTRY_ORG/stx-$DOCKER_BASE_OS:$base_image_tag $reg/stx-$DOCKER_BASE_OS:$base_image_tag"
        stx_docker_cmd $DRY_RUN_ARG "docker push $reg/stx-$DOCKER_BASE_OS:$base_image_tag"
    done
fi

