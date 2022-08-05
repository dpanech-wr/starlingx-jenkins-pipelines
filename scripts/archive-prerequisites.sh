#!/bin/bash

set -e
source $(dirname "$0")/lib/job_utils.sh

require_env BUILD_RT

load_build_env

set -x

if [[ -d "$BUILD_HOME/mirrors" ]] ; then
    mkdir -p "$BUILD_OUTPUT_HOME"
    ln -sfn "$BUILD_HOME/mirrors" "$BUILD_OUTPUT_HOME/"
fi
