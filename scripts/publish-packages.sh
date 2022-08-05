#!/bin/bash

#set -e

source $(dirname "$0")/lib/job_utils.sh || exit 1
source $(dirname "$0")/lib/publish_utils.sh || exit 1

require_env BUILD_RT || exit 1
require_env BUILD_ISO || exit 1

load_build_env || exit 1

unset GREP_OPTIONS GREP_COLORS GREP_COLOR

DEB_REPO_ORIGIN="starlingx"

BUILD_TYPES=("std")
if $BUILD_RT || $BUILD_ISO; then
    BUILD_TYPES+=("rt")
fi

PACKAGE_OUTPUTS_ROOT="$BUILD_OUTPUT_HOME/$WORKSPACE_ROOT_SUBDIR"
TEMP_DIR="$BUILD_OUTPUT_HOME/tmp"

do_publish_package_sources_and_binaries() {
    local src_dir="$1"
    local sources_dst_root="$2"
    local packages_dst_root="$3"
    local checksums_filename="$4"
    local published_checksum_files_list_file="$5"

    local src_root
    src_root="$(dirname "$src_dir")"

    local subdir
    subdir="$(basename "$src_dir")"

    sources_dst_dir="$sources_dst_root/$subdir"
    packages_dst_dir="$packages_dst_root"
    mkdir -p "$sources_dst_dir" "$packages_dst_dir"
    rm -f "$sources_dst_dir/$checksums_filename"
    find "$src_root/$subdir" -mindepth 1 -maxdepth 1 \
                             -type f \
                             -not -name '*buildinfo' \
                             -not -name '*changes' \
                             -not -name '*build' \
                             -not -name '*log' \
        | while read filename ; do
            if [[ "$filename" =~ [.]u?deb$ ]] ; then
                dst_dir="$packages_dst_dir"
            else
                dst_dir="$sources_dst_dir"
            fi
            publish_file "$filename" "$dst_dir" "$published_checksum_files_list_file" >>"$dst_dir/$checksums_filename" || exit 1
        done
    check_pipe_status || exit 1
}

publish_package_sources_and_binaries() {
    local checksum_files_list_file="$TEMP_DIR/published_package_checksum_files"

    # Find old checksums
    find_checksum_files "${PUBLISH_SUBDIR}/outputs/std/packages" \
                        "${PUBLISH_SUBDIR}/outputs/rt/packages" \
        >"$checksum_files_list_file" || exit 1


    # copy/link package files
    local build_type
    for build_type in "${BUILD_TYPES[@]}" ; do

        notice "publishing $build_type package files"
        local output_root="$PACKAGE_OUTPUTS_ROOT/$build_type"
        local sources_dst_root="$PUBLISH_DIR/outputs/$build_type/sources"
        local packages_dst_dir="$PUBLISH_DIR/outputs/$build_type/packages"

        local -a find_cmd=(
            find "$output_root" -mindepth 1 -maxdepth 1 \
                                -type d \
                                -not -name stamp \
                                -not -name build-helm \
                                -not -name build-images \
                                -not -name build-wheels'*' \
        )

        if [[ -n "$PARALLEL" ]] ; then
            (
                export -f check_pipe_status publish_file do_publish_package_sources_and_binaries
                "${find_cmd[@]}" | sort | $PARALLEL \
                    do_publish_package_sources_and_binaries '{}' "$sources_dst_root" "$packages_dst_dir" \
                        "$CHECKSUMS_FILENAME" "$checksum_files_list_file"
                check_pipe_status || exit 1
            )
            check_pipe_status || exit 1
        else
            "${find_cmd[@]}" | sort | while read src_dir ; do
                do_publish_package_sources_and_binaries "$src_dir" "$sources_dst_root" "$packages_dst_dir" \
                    "$CHECKSUMS_FILENAME" "$checksum_files_list_file" || exit 1
            done
            check_pipe_status || exit 1
        fi

        notice "creating meta data in $packages_dst_dir"
        make_deb_repo --origin="$DEB_REPO_ORIGIN" "$packages_dst_dir" || exit 1
    done
}

publish_3rdparty_binaries() {
    local src_dir="$BUILD_OUTPUT_HOME/mirrors/starlingx/binaries"
    local dst_dir="$PUBLISH_DIR/inputs/packages"
    local checksum_files_list_file="$TEMP_DIR/published_3rdparty_binaries_checksum_files"
    local checksum_file="$dst_dir/$CHECKSUMS_FILENAME"
    [[ -d "$src_dir" ]] || return

    notice "publishing 3rd-party binaries"
    mkdir -p "$dst_dir"
    rm -f "$checksum_file"
    find_checksum_files "${PUBLISH_SUBDIR}/inputs/packages" >"$checksum_files_list_file" || exit 1

    local -a find_cmd=(
        find "$src_dir" -mindepth 1 -maxdepth 1 -type f \( -name '*.deb' -o -name '*.udeb' \)
    )

    if [[ -n "$PARALLEL" ]] ; then
        (
            export -f check_pipe_status publish_file do_publish_package_files
            "${find_cmd[@]}" | sort | $PARALLEL \
                publish_file '{}' "$dst_dir" "$checksum_files_list_file" >>"$checksum_file"
            check_pipe_status || exit 1
        )
        check_pipe_status || exit 1
    else
        "${find_cmd[@]}" | sort | while read filename ; do
            publish_file "$filename" "$dst_dir" "$checksum_files_list_file" >>$checksum_file || exit 1
        done
        check_pipe_status || exit 1
    fi

    notice "creating meta data in $dst_dir"
    make_deb_repo --origin="$DEB_REPO_ORIGIN" "$dst_dir" || exit 1
}

publish_3rdparty_sources() {
    local src_root_dir="$BUILD_OUTPUT_HOME/mirrors/starlingx/sources"
    local dst_root_dir="$PUBLISH_DIR/inputs/sources"
    local checksum_files_list_file="$TEMP_DIR/published_3rdparty_sources_checksum_files"
    [[ -d "$src_root_dir" ]] || return

    notice "publishing 3rd-party sources"
    find_checksum_files "${PUBLISH_SUBDIR}/outputs/std/sources" \
                        "${PUBLISH_SUBDIR}/outputs/rt/sources" \
                        "${PUBLISH_SUBDIR}/inputs/sources" \
        >"$checksum_files_list_file" || exit 1

    local -a find_cmd=(
        find "$src_root_dir" -mindepth 1 -maxdepth 1 -type d
    )

    if [[ -n "$PARALLEL" ]] ; then
        (
            export -f check_pipe_status publish_file do_publish_3rdparty_sources
            "${find_cmd[@]}" | sort | $PARALLEL \
                do_publish_3rdparty_sources \
                    '{}' "$dst_root_dir" "$checksum_files_list_file" "$CHECKSUMS_FILENAME"
            check_pipe_status || exit 1
        )
        check_pipe_status || exit 1
    else
        "${find_cmd[@]}" | sort | while read src_dir ; do
            do_publish_3rdparty_sources \
                "$src_dir" "$dst_root_dir" "$checksum_files_list_file" "$CHECKSUMS_FILENAME"
        done
        check_pipe_status || exit 1
    fi
}
do_publish_3rdparty_sources() {
    local src_dir="$1"
    local dst_root_dir="$2"
    local checksum_files_list_file="$3"
    local checksums_filename="$4"

    local subdir
    subdir="$(basename "$src_dir")" || exit 1

    local dst_dir="$dst_root_dir/$subdir"
    mkdir -p "$dst_dir" || exit 1

    local checksum_file="$dst_dir/$checksums_filename"
    rm -f "$checksum_file" || exit 1

    find "$src_dir" -mindepth 1 -maxdepth 1 -type f | sort | (
        while read filename ; do
            #echo "filename=$filename" >&2
            #echo "dst_root_dir=$dst_root_dir subdir=$subdir" >&2
            publish_file "$filename" "$dst_dir" "$checksum_files_list_file" >>"$checksum_file" || exit 1
        done
    )
    check_pipe_status || exit 1
}

if $DRY_RUN ; then
    bail "DRY_RUN=false is not supported, bailing out"
fi

mkdir -p "$TEMP_DIR"
mkdir -p "$PUBLISH_ROOT"
publish_3rdparty_sources
publish_3rdparty_binaries
publish_package_sources_and_binaries
