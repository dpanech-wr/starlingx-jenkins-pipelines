#!/bin/bash

set -e
source $(dirname "$0")/lib/job_utils.sh

load_build_env

#VERBOSE_ARG="--verbose"

dir_is_empty() {
    if [[ -d "$1" ]] ; then
        [[ $(find "$1" -mindepth 1 -maxdepth 1 -print -quit | wc -l) -le 0 ]]
    else
        return 0
    fi
}

if ! dir_is_empty "$BUILD_HOME/workspace/helm-charts" ; then
    my_user="$(id -u)"
    my_group="$(id -g)"
    if [[ ! -d "$BUILD_OUTPUT_HOME/workspace/helm-charts" ]] ; then
        mkdir "$BUILD_OUTPUT_HOME/workspace/helm-charts"
    fi
    safe_copy_dir $DRY_RUN_ARG $VERBOSE_ARG --delete --chown $my_user:$my_group \
        "$BUILD_HOME/workspace/helm-charts/" \
        "$BUILD_OUTPUT_HOME/workspace/helm-charts/"

    notice "Helm charts archived in $BUILD_OUTPUT_HOME/workspace/helm-charts"
fi
