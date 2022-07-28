#!/bin/bash

set -e
source $(dirname "$0")/../lib/job_utils.sh

load_build_env

echo "BUILD_OUTPUT_HOME_URL=$BUILD_OUTPUT_HOME_URL"
