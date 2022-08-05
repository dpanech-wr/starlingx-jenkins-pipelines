#!/bin/bash

set -e
source $(dirname "$0")/lib/job_utils.sh

require_env BUILD_HOME
require_env BUILD_ISO

load_build_env

$BUILD_ISO || bail "BUILD_ISO=false, bailing out"

notice "building STD ISO"
stx_docker_cmd $DRY_RUN_ARG "build-image"
