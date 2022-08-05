#!/bin/bash

set -e
source $(dirname "$0")/lib/job_utils.sh

require_env BUILD_HOME
require_env BUILD_STREAM
require_env TIMESTAMP

load_build_env

$DRY_RUN && exit 0 || :

notice "publishing $DOCKER_BASE_OS $BUILD_STREAM docker image lists"
src_dir="$STX_BUILD_HOME/workspace/std/build-images"
dst_dir="$PUBLISH_DIR/outputs/docker-images"

mkdir -p "$dst_dir"
declare -a find_args
or=
for os in $(echo $DOCKER_OS_LIST | sed 's/,/ /g') ; do
    find_args+=(
        $or
        "-name" "images-$os-$BUILD_STREAM-versioned.lst" -o
        "-name" "images-$os-$BUILD_STREAM-latest.lst"
    )
    or="-or"
done
if [[ ${#find_args[@]} -gt 0 ]] ; then
    for src in $(find "$src_dir" -maxdepth 1 -type f \( "${find_args[@]}" \) ) ; do
        cp -v "$src" "$dst_dir/"
    done
fi
