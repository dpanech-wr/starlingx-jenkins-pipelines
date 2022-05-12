#!/bin/bash

set -e
source $(dirname "$0")/../lib/job_utils.sh

load_build_env

$DRY_RUN && bail "DRY_RUN not supported, bailing out" || :

src_dir="$BUILD_OUTPUT_HOME/$WORKSPACE_ROOT_SUBDIR/std/build-helm/stx"
dst_dir="$PUBLISH_DIR/outputs/helm-charts"

files="$(
    if [[ -d "$src_dir" ]] ; then
        find "$src_dir" -mindepth 1 -maxdepth 1 -xtype f -name "*.tgz" || exit 1
    fi
)"
if [[ -n "$files" ]] ; then
    notice "copying helm charts to $dst_dir"
    mkdir -p "$dst_dir"
    echo "$files" | xargs -r \cp --force --no-dereference --preserve=mode,timestamps,links -t "$dst_dir"
fi

