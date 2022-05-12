#!/bin/bash

set -e
source $(dirname "$0")/../lib/job_utils.sh

require_env BUILD_HOME
require_env DRY_RUN

load_build_env

BUILD_STREAMS="stable dev"
BUILD_TAGS="latest versioned"

# find image dirs relative to WORKSPACE_ROOT
declare -a image_dirs
if [[ -d "$WORKSPACE_ROOT/std/build-images" ]] ; then
    image_dirs+=("std/build-images")
fi
if [[ -d "$WORKSPACE_ROOT/rt/build-images" ]] ; then
    image_dirs+=("rt/build-images")
fi
# copy any extra image-*.lst files to workspace so that
# build containers can see them
if [[ -d "$EXTRA_IMAGE_RECORD_DIR" ]] ; then
    if ! $DRY_RUN ; then
        rm -rf --one-file-system "$WORKSPACE_ROOT/extra-image-records"/*
        mkdir -p "$WORKSPACE_ROOT/extra-image-records"
        find "$EXTRA_IMAGE_RECORD_DIR" \
                -mindepth 1 -maxdepth 1 -name 'images-*.lst' \
                -exec \cp --force --preserve=links --no-dereference -t "$WORKSPACE_ROOT/extra-image-records" '{}' '+' \
            || exit 1
        image_dirs+=('extra-image-records')
    fi
fi

build_helm_charts() {
    local cmd="$1"
    stx_docker_cmd $DRY_RUN_ARG "set -e ; cd \"\$MY_REPO/build-tools\" ; export PATH=\"\$PWD:\$PATH\" ; $cmd"
}

# call build-helm-charts.sh in container for each stream/tag
if [[ "${#image_dirs[@]}" -gt 0 ]] ; then
    for build_stream in $BUILD_STREAMS ; do
        for build_tag in $BUILD_TAGS ; do
            for os in $DOCKER_BASE_OS ; do
                label="${os}-${build_stream}-${build_tag}"
                distroless_label="distroless-${build_stream}-${build_tag}"
                # look for image list files
                image_arg=$(
                    sep=
                    ( cd "$WORKSPACE_ROOT" && find "${image_dirs[@]}"  \
                        -mindepth 1 -maxdepth 1 -name "images-${label}.lst" -o -name "images-${distroless_label}.lst" ; ) \
                    | while read image_list_file ; do
                        echo -n "${sep}\$MY_WORKSPACE/${image_list_file}"
                        sep=","
                    done
                    check_pipe_status || exit 1
                )
                check_pipe_status || exit 1

                if [[ -n "$image_arg" ]] ; then
                    cmd="build-helm-charts.sh"
                    cmd+=" --os ${os}"
                    cmd+=" --image-record ${image_arg}"
                    cmd+=" --label '${label}'"
                    cmd+=" --verbose"
                    cmd+=" | tee \"\$MY_WORKSPACE/helm-${label}.log\""
                    cmd+=" ; [[ \${PIPESTATUS[0]} -eq 0 ]]"
                    build_helm_charts "$cmd" || exit 1
                fi
            done
        done
    done
fi
