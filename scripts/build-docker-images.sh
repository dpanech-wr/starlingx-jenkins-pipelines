#!/bin/bash

set -e
source $(dirname "$0")/../lib/job_utils.sh

require_env BUILD_HOME
require_env DRY_RUN
require_env USE_DOCKER_CACHE
require_env BUILD_STREAM stable
require_env PUSH_DOCKER_IMAGES
declare_env DOCKER_IMAGE_LIST
declare_env DOCKER_IMAGE_BASE

load_build_env

DOCKER_OS_LIST="$DOCKER_BASE_OS distroless"
wheels_file="std/build-wheels-$DOCKER_BASE_OS-$BUILD_STREAM/stx-$DOCKER_BASE_OS-$BUILD_STREAM-wheels.tar"

#require_file "$HOST_WORKSPACE/$wheels_file"

if [[ -n "$DOCKER_IMAGE_BASE" ]] ; then
    base_img="$DOCKER_IMAGE_BASE"
else
    base_image_tag="$BUILD_BRANCH-$BUILD_STREAM-$TIMESTAMP"
    base_img="$DOCKER_REGISTRY/$DOCKER_REGISTRY_ORG/stx-$DOCKER_BASE_OS:$base_image_tag"
fi

declare -a cmd=(
    "./build-stx-images.sh"
    "--attempts=$DOCKER_BUILD_RETRY_COUNT"
    "--stream=$BUILD_STREAM"
    "--base=$base_img"
    "--no-pull-base"
    "--version=$TIMESTAMP"
    "--prefix=$BUILD_BRANCH"
    "--registry=$DOCKER_REGISTRY"
    "--user=$DOCKER_REGISTRY_ORG"
    "--latest"
)

if [[ -f "$WORKSPACE_ROOT/$wheels_file" ]] ; then
    cmd+=("--wheels=\$MY_WORKSPACE/$wheels_file")
fi

if [[ "$USE_DOCKER_CACHE" == true ]] ; then
    cmd+=("--cache")
fi

# add --only if $DOCKER_IMAGE_LIST contains anything
if [[ -n "$DOCKER_IMAGE_LIST" ]] ; then
    comma=
    only=
    for img in $(echo "$DOCKER_IMAGE_LIST" | sed 's/[,;]+/ /g') ; do
        [[ -n "$img" ]] || continue
        only+="${only}${comma}${img}"
        comma=","
    done
    if [[ -n "$only" ]] ; then
        cmd+=("--only=$only")
    fi
fi

# build-stx-base.sh can only push to one repo. We will push to any
# additional repos manually.
if $PUSH_DOCKER_IMAGES ; then
    cmd+=("--push")
fi

# Usage: retag_and_push $IMAGE_LIST_FILE
retag_and_push() {
    if [[ -n "$EXTRA_REGISTRY_PREFIX_LIST" ]] ; then
        local list_file="$1"
        local src_img
        for src_img in $(grep -E -v '^\s*(#.*)?$' $list_file) ; do
            local reg_prefix base_img
            base_img="${src_img#$DOCKER_REGISTRY/$DOCKER_REGISTRY_ORG}"
            if [[ "$base_img" == "$src_img" ]] ; then
                die "$list_file: unexpected image \"$src_img\""
            fi
            for reg_prefix in $EXTRA_REGISTRY_PREFIX_LIST ; do
                local dst_img="$(echo "${reg_prefix}/$base_img" | sed 's!//*!/!g')"
                stx_docker_cmd $DRY_RUN_ARG "docker tag $src_img $dst_img"
                stx_docker_cmd $DRY_RUN_ARG "docker push $dst_img"
            done
        done
    fi
}

# build them
lists_dir="$HOST_WORKSPACE/std/build-images"
for os in $(echo $DOCKER_OS_LIST | sed 's/,/ /g') ; do
    list_file="$lists_dir/images-$os-$BUILD_STREAM-versioned.lst"
    notice "building $BUILD_STREAM $os images"
    $DRY_RUN || rm -f "$list_file"
    stx_docker_cmd $DRY_RUN_ARG "cd \$MY_REPO/build-tools/build-docker-images && ${cmd[*]} --os=$os"
    if $PUSH_DOCKER_IMAGES && [[ -f "$list_file" ]] ; then
        retag_and_push "$list_file"
    fi
done

