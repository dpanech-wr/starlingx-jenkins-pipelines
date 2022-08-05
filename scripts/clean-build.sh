#!/bin/bash

set -e
source $(dirname "$0")/lib/job_utils.sh

require_env BUILD_HOME
require_env CLEAN_PACKAGES
require_env CLEAN_REPOMGR
require_env CLEAN_DOWNLOADS
require_env CLEAN_DOCKER
require_env CLEAN_ISO
require_env IMPORT_BUILD
declare_env IMPORT_BUILD_DIR

load_build_env

#VERBOSE_ARG=--verbose
VERBOSE_ARG=

clean_or_import() {
    local -a exclude_args
    while [[ "$1" == "--exclude" ]] ; do
        exclude_args+=("$1" "$2")
        shift 2
    done
    local src_subdir="$1"
    local dst_subdir="$2"
    local clean_requested="$3"
    local allow_merge="${4:-false}"

    local src_dir="$IMPORT_BUILD_DIR/$src_subdir"
    if $IMPORT_BUILD && [[ -n "$IMPORT_BUILD_DIR" ]] && [[ -d "$src_dir" ]] ; then
        local real_src_dir
        real_src_dir="$(readlink -f "$src_dir")"
        local delete_arg
        if ! $allow_merge ; then
            delete_arg="--delete"
        fi
        notice "importing $src_subdir from $IMPORT_BUILD_DIR"
        dst_dir="$BUILD_HOME/$dst_subdir"
        mkdir -p "$dst_dir"
        safe_copy_dir $DRY_RUN_ARG $VERBOSE_ARG $delete_arg "${exclude_args[@]}" \
            "$real_src_dir/" "$dst_dir/"
        return
    fi
    if $clean_requested ; then
        notice "removing $dst_subdir"
        safe_rm $DRY_RUN_ARG $VERBOSE_ARG "$BUILD_HOME/$dst_subdir"/*
    fi
}

if [[ -d "$BUILD_HOME/localdisk/loadbuild" ]] ; then
    # If user has changed, there may be subdirectories remaining under
    # the innder localdisk/loadbuild named after a different user. Delete them.
    declare -a rm_dirs
    readarray -t rm_dirs < <(
        find "$BUILD_HOME/localdisk/loadbuild" -mindepth 1 -maxdepth 1 \
            -type d \! -name "$USER"
    )
    # If project name has changed, there may be subdirectories named after
    # the old project name(s), delete them too.
    if [[ -d "$BUILD_HOME/localdisk/loadbuild/$USER" ]] ; then
        readarray -O "${#rm_dirs[@]}" -t rm_dirs < <(
            find "$BUILD_HOME/localdisk/loadbuild/$USER" -mindepth 1 -maxdepth 1 \
                -type d \! -name "$PROJECT"
        )
    fi

    if [[ "${#rm_dirs[@]}" -gt 0 ]] ; then
        safe_rm $DRY_RUN_ARG $VERBOSE_ARG "${rm_dirs[@]}"
    fi
fi

clean_or_import --exclude /meta-lat --exclude /tmp --exclude /sign \
                "workspace" "$WORKSPACE_ROOT_SUBDIR" $CLEAN_PACKAGES

clean_or_import "mirrors"   "mirrors"                $CLEAN_DOWNLOADS  true
clean_or_import "aptly"     "aptly"                  $CLEAN_REPOMGR
clean_or_import "docker"    "docker"                 $CLEAN_DOCKER
clean_or_import "docker"    "lat"                    $CLEAN_ISO

# these files can't be imported, always delete them
notice "removing misc files"
safe_rm $DRY_RUN_ARG $VERBOSE_ARG \
    "$BUILD_HOME"/localdisk/*.log \
    "$BUILD_HOME"/localdisk/channel \
    "$BUILD_HOME"/localdisk/deploy \
    "$BUILD_HOME"/localdisk/pkgbuilder \
    "$BUILD_HOME"/localdisk/workdir \
    "$BUILD_HOME"/localdisk/sub_workdir \
    "$BUILD_HOME"/localdisk/tmp \
    "$BUILD_HOME"/lat \
    \
    "$BUILD_OUTPUT_HOME"/{SUCCESS,FAILURE,NEED_BUILD,NO_BUILD_REQUIRED,LAST_COMMITS*,CHANGES}
