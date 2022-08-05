#!/bin/bash

set -e
source $(dirname "$0")/lib/job_utils.sh

set -x
load_build_env

######################################################
# stx.conf
######################################################

rm -f stx.conf
unset DEBIAN_DISTRIBUTION DEBIAN_SNAPSHOT DEBIAN_SECURITY_SNAPSHOT
source ./import-stx
stx config --add builder.myuname "$USER"
stx config --add builder.uid "$USER_ID"

# Embedded in ~/localrc of the build container
stx config --add project.gituser "$USER_NAME"
stx config --add project.gitemail $USER_EMAIL

# This will be included in the name of your build container and the basename for $MY_REPO_ROOT_DIR
stx config --add project.name "$PROJECT"
stx config --add project.proxy false

# debian distro & urls
if [[ -n "$DEBIAN_SNAPSHOT_BASE" ]] ; then
    stx config --add project.debian_snapshot_base "$DEBIAN_SNAPSHOT_BASE"
fi
if [[ -n "$DEBIAN_SECURITY_SNAPSHOT_BASE" ]] ; then
    stx config --add project.debian_security_snapshot_base "$DEBIAN_SECURITY_SNAPSHOT_BASE"
fi

notice "$PWD/stx.conf"
cat stx.conf

######################################################
# BUILD file
######################################################

build_info_file="$WORKSPACE_ROOT/BUILD"
release_info_file="${REPO_ROOT}/${RELEASE_INFO_FILE}"

if [[ -n "$SW_VERSION" ]] ; then
    sw_version="$SW_VERSION"
elif [[ -n "$release_info_file" ]] ; then
    sw_version=$(grep "PLATFORM_RELEASE=" "$release_info_file" | cut -d = -f 2 | tr -d '"')
    [[ -n "$sw_version" ]] || die "unable to determine SW_VERSION"
else
    die "unable to determine SW_VERSION"
fi

cat >"$build_info_file" <<_END
###
### Wind River Cloud Platform
###     Release $sw_version
###
###     Wind River Systems, Inc.
###

SW_VERSION="$sw_version"
BUILD_TARGET="Host Installer"
BUILD_TYPE="Formal"
BUILD_ID="$TIMESTAMP"
SRC_BUILD_ID="$BUILD_NUMBER"

JOB="$JOB_NAME"
BUILD_BY="$USER"
BUILD_NUMBER="$BUILD_NUMBER"
BUILD_HOST="$HOSTNAME"
BUILD_DATE="$(date '+%F %T %z')"
_END

notice "$build_info_file"
cat "$build_info_file"

