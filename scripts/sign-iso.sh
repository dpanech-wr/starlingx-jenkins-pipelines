#!/bin/bash

set -e
source $(dirname "$0")/../lib/job_utils.sh

require_env BUILD_HOME
require_env BUILD_ISO
require_env BUILD_RT

load_build_env

require_env SIGN_ISO
$SIGN_ISO || bail "SIGN_ISO=false, bailing out"

require_env SIGNING_SERVER
require_env SIGNING_USER

$BUILD_ISO || bail "BUILD_ISO=false, bailing out"
$SIGN_ISO || bail "SIGN_ISO=false, bailing out"
[[ -n "$SIGNING_SERVER" ]] || bail "SIGNING_SERVER is empoty, bailing out"

sign_iso() {
    local iso_file="$1"
    (
        export MY_REPO=$REPO_ROOT/cgcs-root
        export MY_WORKSPACE=$WORKSPACE_ROOT
        export PATH=$MY_REPO/build-tools:$PATH:/usr/local/bin
        sig_file="${iso_file%.iso}.sig"
        maybe_run rm -f "$sig_file"
        maybe_run sign_iso_formal.sh "$iso_file" || die "failed to sign ISO"
        if ! $DRY_RUN ; then
            [[ -f "$sig_file" ]] || die "failed to sign ISO"
            info "created signature $sig_file"
        fi
    )
}


declare -a iso_files
iso_files+=($BUILD_HOME/localdisk/deploy/starlingx-intel-x86-64-cd.iso)

for iso_file in "${iso_files[@]}" ; do
    if [[ -L "$iso_file" ]] ; then
        iso_link_target="$(readlink "$iso_file")" || exit 1
        [[ -n "$iso_link_target" ]] || die "failed to read symlink $iso_file"
        [[ ! "$iso_link_target" =~ ^/ ]] || die "$iso_file: link target must not include slashes"
        real_iso_file="$(dirname "$iso_file")/$iso_link_target"
        sign_iso "$real_iso_file"
        sig_file="${iso_file%.iso}.sig"
        sig_link_target="${iso_link_target%.iso}.sig"
        if ! $DRY_RUN ; then
            ln -sfn "$sig_link_target" "$sig_file" || exit 1
            info "created signature link $sig_file => $sig_link_target"
        fi
    else
        sign_iso "$iso_file"
    fi
done
