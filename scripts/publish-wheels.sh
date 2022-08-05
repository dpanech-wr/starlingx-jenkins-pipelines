#!/bin/bash

set -e
source $(dirname "$0")/lib/job_utils.sh

require_env BUILD_HOME
require_env TIMESTAMP
require_env BUILD_STREAM

load_build_env

$DRY_RUN && bail "DRY_RUN not supported, bailing out" || :

src_dir="$STX_BUILD_HOME/workspace/std/build-wheels-$DOCKER_BASE_OS-$BUILD_STREAM"
dst_dir="$PUBLISH_DIR/outputs/wheels"

declare -a wheels_files=(
    "$src_dir/stx-$DOCKER_BASE_OS-$BUILD_STREAM-wheels.tar"
    "$src_dir/stx-$DOCKER_BASE_OS-$BUILD_STREAM-wheels-py2.tar"
)

declare -a existing_wheels_files
for f in "${wheels_files[@]}" ; do
    if [[ -f "$f" ]] ; then
        existing_wheels_files+=("$f")
    fi
done

if [[ "${#existing_wheels_files[@]}" -gt 0 ]] ; then
    notice "publish wheels files to dst_dir"
    for wheels_file in "${existing_wheels_files[@]}" ; do
        [[ -f "$wheels_file" ]] || continue
        \cp --force --no-dereference --preserve=mode,timestamps,links -t "$dst_dir" "$wheels_file"
    done
fi
