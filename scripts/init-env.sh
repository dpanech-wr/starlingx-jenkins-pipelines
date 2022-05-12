#!/bin/bash

set -e
source $(dirname "$0")/../lib/job_utils.sh

if [[ -d "$BUILD_HOME" ]] ; then
    info "creating $BUILD_HOME"
    mkdir -p "$BUILD_HOME"
fi

if [[ ! -f "$BUILD_HOME/build.conf" ]] ; then
    info "$BUILD_HOME/build.conf: file not found"
    info "creating $BUILD_HOME/build.conf.example"
    cp "$TOP_SCRIPTS_DIR/templates/build.conf.example.in" "$BUILD_HOME/build.conf.example"
    info "Please use the example file as the starting point"
    exit 1
fi

load_build_config

set -x

for dir in "$BUILD_OUTPUT_ROOT" ; do
    if [[ ! -d "$dir" ]] ; then
        info "creating $dir"
        mkdir -p "$dir"
    fi
done

# Install source_me.sh to $BUILD_HOME
info "creating $BUILD_HOME/source_me.sh"
cp "$TOP_SCRIPTS_DIR/templates/source_me.sh.in" "$BUILD_HOME/source_me.sh"

# Delete old jenkins job list
if [[ -d "$BUILD_HOME/jenkins" ]] ; then
    rm -f "$BUILD_HOME/jenkins/builds.txt"
else
    mkdir "$BUILD_HOME/jenkins"
fi

# Create symlinks
mkdir -p "$BUILD_HOME/$REPO_ROOT_SUBDIR" "$BUILD_HOME/$WORKSPACE_ROOT_SUBDIR"
ln -sfn "$REPO_ROOT_SUBDIR" "$BUILD_HOME/repo"
ln -sfn "$WORKSPACE_ROOT_SUBDIR" "$BUILD_HOME/workspace"
