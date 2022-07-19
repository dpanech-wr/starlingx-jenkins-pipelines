#!/bin/bash

set -e
source $(dirname "$0")/../lib/job_utils.sh
require_env BUILD_HOME

require_env BUILD_PACKAGES
declare_env BUILD_PACKAGES_LIST
require_env BUILD_RT
require_env CLEAN_PACKAGES

load_build_env

$BUILD_PACKAGES || bail "BUILD_PACKAGES=false, skipping build"

BUILD_PACKAGES_LIST=$(trim $(echo $BUILD_PACKAGES_LIST | sed 's/,/ /g'))
info "CLEAN_PACKAGES=$CLEAN_PACKAGES"
info "BUILD_PACKAGES_LIST=$BUILD_PACKAGES_LIST"

# build std and rt as we have a single iso for both
build_types="std,rt"

count=0
success=0
# Build all packages a few times
declare -a extra_args
while [[ $count -lt $BUILD_PACKAGES_ITERATIONS ]] ; do
    extra_args=()

#    # clean on 1st iteration only if CLEAN_BUILD was set and we are building
#    # specific packages
#    if [[ $count == 0 ]] && $CLEAN_PACKAGES && [[ -n $BUILD_PACKAGES_LIST ]] ; then
#        extra_args+=("-c")
#    fi

    # Either build specific or all packages
    if [[ -n $BUILD_PACKAGES_LIST ]] ; then
        extra_args+=("-p" "$(echo $BUILD_PACKAGES_LIST | sed 's/ /,/g')")
    else
        extra_args+=("-a")
    fi

    # buld'em
    if stx_docker_cmd $DRY_RUN_ARG $VEBOSE_ARG "build-pkgs ${extra_args[*]} -b $build_types" ; then
        success=1
    else
        success=0
    fi
    let ++count
done
if [[ $success -ne 1 ]] ; then
    notice "Failed to build packages after $BUILD_PACKAGES_ITERATIONS iterations"
    exit 1
fi
