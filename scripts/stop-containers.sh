#!/bin/bash

set -e
source $(dirname "$0")/../lib/job_utils.sh

require_env BUILD_HOME
load_build_config

if [[ ! -f "$BUILD_HOME/$REPO_ROOT_SUBDIR/stx-tools/import-stx" ]] ; then
    warn "$BUILD_HOME/$REPO_ROOT_SUBDIR/stx-tools/import-stx: file doesn't exist"
    warn "Can't stop containers, bailing out"
    exit 0
fi

load_build_env
stx control stop || true
