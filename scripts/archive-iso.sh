#!/bin/bash

set -e
source $(dirname "$0")/../lib/job_utils.sh

require_env BUILD_RT

load_build_env

LAT_SUBDIR="localdisk/deploy"

#VERBOSE_ARG="--verbose"


$BUILD_ISO || bail "BUILD_ISO=false, bailing out"

declare -a iso_files
mkdir -p "${BUILD_OUTPUT_HOME}/localdisk"

src_dir="${BUILD_HOME}/${LAT_SUBDIR}"
dst_dir="${BUILD_OUTPUT_HOME}/${LAT_SUBDIR}"
if [[ -d "${src_dir}" ]] ; then
    notice "archving $src_dir"
    mkdir -p "$dst_dir"
    safe_copy_dir $DRY_RUN_ARG $VERBOSE_ARG "${src_dir}/" "${dst_dir}/"
    if [[ -e "${dst_dir}/deploy" ]] ; then
        iso_files+=($(find "${dst_dir}/deploy" -mindepth 1 -maxdepth 1 -type f))
    fi
fi

if [[ "${#iso_files[@]}" -gt 0 ]] ; then
    notice "changing file ownership to $USER"
    safe_chown $DRY_RUN_ARG $VERBOSE_ARG "$USER:" "${iso_files[@]}"
fi


