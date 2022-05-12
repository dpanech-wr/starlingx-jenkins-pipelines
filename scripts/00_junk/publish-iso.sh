#!/bin/bash

#
# Copyright (c) 2022 Wind River Systems, Inc.
#
# SPDX-License-Identifier: Apache-2.0
#

set -e

source $(dirname "$0")/../lib/job_utils.sh

require_env BUILD_RT

load_build_env

if $DRY_RUN ; then
    bail "DRY_RUN=true not supported, bailing out"
fi

DISTRTO=debian
declare -a BUILD_TYPES=("std")
if $BUILD_RT ; then
    BUILD_TYPES+=("rt")
fi

make_deb_repo() {
    gen_deb_repo_meta_data $DRY_RUN_ARG "$@"
}

hardlink_or_copy_file() {
    local src_file="$1"
    local dst_file="$2"
    : <"$src_file" || exit 1
    rm -f "$dst_file"
    ln -n "$src_file" "$dst_file" || cp "$src_file" "$dst_file" || exit 1
}

# -----------------------

set -x

RETRIES=2
RETRY_INTERVAL_SEC=5

echo "PUBLISH: TIMESTAMP=${TIMESTAMP}"
echo "PUBLISH: BUILD_OUTPUT_HOME=${BUILD_OUTPUT_HOME}"
echo "PUBLISH: BUILD_HOME=${BUILD_HOME}"
echo "PUBLISH: DISTRO=${DISTRO}"
echo "PUBLISH: MANIFEST_BRANCH=${MANIFEST_BRANCH}"
export

source ${LIB_DIR}/retries.sh
source ${LIB_DIR}/file_utils.sh

function with_default_retries {
    local cmd=$1
    shift 1
    with_retries ${RETRIES:-1} ${RETRY_INTERVAL_SEC:-1} "${cmd}" "$@"
}

PUBLISH_OUTPUTS_DIR="${PUBLISH_DIR}/outputs"

for BT in "${BUILD_TYPES[@]}" ; do
    ISO_OUTPUT="${BUILD_OUTPUT_HOME}/localdisk/lat/${BT}/deploy"
    if [ -d "${ISO_OUTPUT}" ]; then
        PUBLISH_ISO_DIR="${PUBLISH_OUTPUTS_DIR}/${BT}/iso"
        with_default_retries mkdir -p ${PUBLISH_ISO_DIR}
        for ISO in $(find ${ISO_OUTPUT} -name 'starlingx*.iso'); do
            if [ "${BT}" == "std" ]; then
                B_NAME=$(basename "${ISO}")
            else
                B_NAME=$(basename "${ISO}" | sed "s/starlingx-/starlingx-${BT}-/")
            fi
            if [ -L "${ISO}" ] ; then
                src_iso="$(readlink -f "${ISO}")" || exit 1
            else
                src_iso="${ISO}"
            fi
            src_sig="${src_iso%.iso}.sig"
            cp_or_link "${src_iso}" "${PUBLISH_ISO_DIR}"
            if [[ -f "$src_sig" ]] ; then
                cp -f "${src_sig}" "${PUBLISH_ISO_DIR}"
            fi
            link_target="$(basename "${src_iso}")"
            if [ "${link_target}" != "${B_NAME}" ] ; then
                ln -s -f -n "${link_target}" "${PUBLISH_ISO_DIR}/${B_NAME}" || exit 1
                sig_link_target="${link_target%.iso}.sig"
                sig_link="${PUBLISH_ISO_DIR}/${B_NAME%.iso}.sig"
                ln -s -f -n "${sig_link_target}" "${sig_link}"
            fi
        done
    fi
done

