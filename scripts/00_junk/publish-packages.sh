#!/bin/bash

#
# Copyright (c) 2022 Wind River Systems, Inc.
#
# SPDX-License-Identifier: Apache-2.0
#

set -e

source $(dirname "$0")/../lib/job_utils.sh

require_env BUILD_RT
declare_env DRY_RUN

load_build_env

BUILD_OUTPUT="$BUILD_OUTPUT_HOME"
PUBLISH_BRANCH_ROOT="$BUILD_OUTPUT_HOME/export"
declare -a BUILD_TYPES=("std")
if $BUILD_RT ; then
    BUILD_TYPES+=("rt")
fi

if $DRY_RUN ; then
    echo "DRY_RUN=true not supported, bailing out"
    exit 0
fi

make_deb_repo() {
    gen_deb_repo_meta_data $DRY_RUN_ARG "$@"
}

# -----------------------

#set -x

RETRIES=2
RETRY_INTERVAL_SEC=5

CHECKSUM_FN=stx-checksums

source ${LIB_DIR}/retries.sh
source ${LIB_DIR}/file_utils.sh

function with_default_retries {
    local cmd=$1
    shift 1
    with_retries ${RETRIES:-1} ${RETRY_INTERVAL_SEC:-1} "${cmd}" "$@"
}

PUBLISH_INPUTS_DIR="${PUBLISH_DIR}/inputs"
PUBLISH_OUTPUTS_DIR="${PUBLISH_DIR}/outputs"

echo "PUBLISH: PUBLISH_ROOT=${PUBLISH_ROOT}"
echo "PUBLISH: PUBLISH_INPUTS_DIR=${PUBLISH_INPUTS_DIR}"
echo "PUBLISH: PUBLISH_OUTPUTS_DIR=${PUBLISH_OUTPUTS_DIR}"

# Search for checksum files
#   $PUBLISH_ROOT/<any layers>/<any timestamps>/$PUBLISH_SUBDIR
CHECKSUM_FILES=$(
    if [[ -d "${PUBLISH_ROOT}" ]] ; then
        { # timestamp dirs
            find "$PUBLISH_ROOT" -regextype posix-extended -mindepth 1 -maxdepth 1 -type d -regex '.*/[0-9]{4}.*$'
        } | { # publish subdir
            while read dir ; do
                if [[ -n "$PUBLISH_SUBDIR" && -d "$dir/$PUBLISH_SUBDIR" ]] ; then
                    echo "$dir/$PUBLISH_SUBDIR"
                fi
            done
        } | { # checksums
            xargs -r -i find '{}' -type f -name "${CHECKSUM_FN}"
        }
    fi
)

PKGS_INPUT="${BUILD_OUTPUT}/mirrors/starlingx/binaries"
if [ -d "${PKGS_INPUT}" ]; then
    PUBLISH_INPUTS_PKG_DIR="${PUBLISH_INPUTS_DIR}/packages"
    with_default_retries mkdir -p ${PUBLISH_INPUTS_PKG_DIR}
    for PKG in $(find ${PKGS_INPUT} -name '*.deb'); do
        with_default_retries cp_or_link "${PKG}" "${PUBLISH_INPUTS_PKG_DIR}" $CHECKSUM_FILES
    done
    get_file_data_from_dir "${PUBLISH_INPUTS_PKG_DIR}" "${PUBLISH_INPUTS_PKG_DIR}/${CHECKSUM_FN}"
    CHECKSUM_FILES+=" ${PUBLISH_INPUTS_PKG_DIR}/${CHECKSUM_FN}" 
    make_deb_repo "${PUBLISH_INPUTS_PKG_DIR}"
fi

SRCS_INPUT="${BUILD_OUTPUT}/mirrors/starlingx/sources"
echo "SRCS_INPUT=$SRCS_INPUT"
if [ -d "${SRCS_INPUT}" ]; then
    PUBLISH_INPUTS_SRC_DIR="${PUBLISH_INPUTS_DIR}/sources"
    echo "PUBLISH_INPUTS_SRC_DIR=$PUBLISH_INPUTS_SRC_DIR"
    for PKG_SRC_INPUT in $(find "${SRCS_INPUT}" -maxdepth 1 -type d) ; do
        PUBLISH_INPUT_SRC_PKG_DIR="${PUBLISH_INPUTS_SRC_DIR}/$(basename "${PKG_SRC_INPUT}")"
        for f in $(find ${PKG_SRC_INPUT} -maxdepth 1 -type f ); do
            with_default_retries mkdir -p ${PUBLISH_INPUT_SRC_PKG_DIR}
            with_default_retries cp_or_link "${f}" "${PUBLISH_INPUT_SRC_PKG_DIR}" $CHECKSUM_FILES
        done
    done
    if [ -d "${PUBLISH_INPUTS_SRC_DIR}" ]; then
        get_file_data_from_dir "${PUBLISH_INPUTS_SRC_DIR}" "${PUBLISH_INPUTS_SRC_DIR}/${CHECKSUM_FN}"
        CHECKSUM_FILES+=" ${PUBLISH_INPUTS_SRC_DIR}/${CHECKSUM_FN}" 
    fi
fi

for BT in "${BUILD_TYPES[@]}" ; do
    BT_OUTPUT="${BUILD_OUTPUT}/localdisk/loadbuild/jenkins/${PROJECT}/${BT}"
    if [ -d "${BT_OUTPUT}" ]; then
        PUBLISH_OUTPUTS_SRC_DIR="${PUBLISH_OUTPUTS_DIR}/${BT}/sources"
        PUBLISH_OUTPUTS_PKG_DIR="${PUBLISH_OUTPUTS_DIR}/${BT}/packages"
        for PKG_OUTPUT in $(find "${BT_OUTPUT}" -maxdepth 1 -type d) ; do
            echo "PKG_OUTPUT=${PKG_OUTPUT}"

            if [ $(find "${PKG_OUTPUT}" -maxdepth 1 -type f -name '*.dsc' | wc -l) -ne 0 ]; then
                PUBLISH_OUTPUTS_SRC_PKG_DIR="${PUBLISH_OUTPUTS_SRC_DIR}/$(basename "${PKG_OUTPUT}")"
                with_default_retries mkdir -p "${PUBLISH_OUTPUTS_SRC_PKG_DIR}"
                for f in $(find ${PKG_OUTPUT} -maxdepth 1 -type f -not -name '*deb' \
                                      -and -not -name '*buildinfo' \
                                      -and -not -name '*changes' \
                                      -and -not -name '*build' \
                                      -and -not -name '*log' ); do
                    with_default_retries cp_or_link "${f}" "${PUBLISH_OUTPUTS_SRC_PKG_DIR}" $CHECKSUM_FILES
                done
            fi

            if [ $(find "${PKG_OUTPUT}" -maxdepth 1 -type f -name '*.deb' | wc -l) -ne 0 ]; then
                with_default_retries mkdir -p "${PUBLISH_OUTPUTS_PKG_DIR}"
                for f in $(find ${PKG_OUTPUT} -maxdepth 1 -type f -name '*deb' ); do
                    with_default_retries cp_or_link "${f}" "${PUBLISH_OUTPUTS_PKG_DIR}" $CHECKSUM_FILES
                done
            fi
        done

        if [ -d "${PUBLISH_OUTPUTS_SRC_DIR}" ]; then
            get_file_data_from_dir "${PUBLISH_OUTPUTS_SRC_DIR}" "${PUBLISH_OUTPUTS_SRC_DIR}/${CHECKSUM_FN}"
            CHECKSUM_FILES+=" ${PUBLISH_OUTPUTS_SRC_DIR}/${CHECKSUM_FN}" 
        fi

        if [ -d "${PUBLISH_OUTPUTS_PKG_DIR}" ]; then
            get_file_data_from_dir "${PUBLISH_OUTPUTS_PKGS_ROOT}" "${PUBLISH_OUTPUTS_PKG_DIR}/${CHECKSUM_FN}"
            CHECKSUM_FILES+=" ${PUBLISH_OUTPUTS_PKG_DIR}/${CHECKSUM_FN}" 
            make_deb_repo "${PUBLISH_OUTPUTS_PKG_DIR}"
        fi
    fi
done
