#!/bin/bash

set -e
source $(dirname "$0")/lib/job_utils.sh
require_env BUILD_HOME
require_env USE_DOCKER_CACHE
require_env DRY_RUN
require_env BUILD_STREAM stable
require_env DOCKER_IMAGE_LIST
require_env FORCE_BUILD_WHEELS

load_build_env

BUILD_STREAM=stable
DOCKER_IMAGE_LIST=$(trim $(echo $DOCKER_IMAGE_LIST | sed 's/,/ /'))

image_requires_wheels() {
    local -a parts
    parts=($(source "$1" && echo "$BUILDER ${LABEL:-$PROJECT}"))
    local builder=${parts[0]}
    local name=${parts[1]}

    if [[ "$builder" != "loci" ]] ; then
        return 1
    fi

    if [[ -n "${DOCKER_IMAGE_LIST}" ]] && ! in_list "$name" "$DOCKER_IMAGE_LIST" ; then
        return 1
    fi

    return 0
}

wheels_required() {
    local -i wheels_images=0

    local projects
    projects="$(cd "$REPO_ROOT" && repo forall -c 'echo $REPO_PATH' 2>/dev/null)"

    local proj
    for proj in $projects ; do
        local os
        for os in $DOCKER_OS_LIST ; do
            local inc
            for inc in $(find "$REPO_ROOT/$proj" -maxdepth 2 -type f -name "${os}_${BUILD_STREAM}_docker_images.inc") ; do
                local basedir
                local dir
                basedir="$(dirname "$inc")"
                for dir in $(grep -E -v '^\s*(#.*)?$' "$inc") ; do
                    local img_dir="$basedir/$dir/$os"
                    if [[ -d "$img_dir" ]] ; then
                        for img_file in $(find "$img_dir" -mindepth 1 -maxdepth 1 -name "*.${BUILD_STREAM}_docker_image") ; do
                            if image_requires_wheels "$img_file" ; then
                                let ++wheels_images
                                echo "${img_file#$REPO_ROOT/}: requires wheels" >&2
                            fi
                        done
                    fi
                done
            done
        done
    done

    [[ $wheels_images -gt 0 ]] && return 0 || return 1
}

if ! $FORCE_BUILD_WHEELS && ! wheels_required ; then
    bail "wheels not required, bailing out"
fi

cmd=(
    "./build-wheel-tarball.sh"
    "--os=$DOCKER_BASE_OS"
    "--stream=$BUILD_STREAM"
    "--attempts=$DOCKER_BUILD_RETRY_COUNT"
)

if [[ "$USE_DOCKER_CACHE" == true ]] ; then
    cmd+=("--cache")
fi

for python_arg in "" "--python2" ; do
    stx_docker_cmd $DRY_RUN_ARG "cd \$MY_REPO/build-tools/build-wheels && ${cmd[*]} $python_arg"
done
