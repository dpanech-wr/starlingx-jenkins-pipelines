#!/bin/bash

set -e
source $(dirname "$0")/lib/job_utils.sh
source $(dirname "$0")/lib/retries.sh

require_env BUILD_HOME
require_env DRY_RUN
require_env REFRESH_SOURCE

load_build_env

RETRIES=3
RETRY_INTERVAL_SEC=15

notice "initializing source repo" \
       "BUILD_HOME=$BUILD_HOME"

mkdir -p "$BUILD_HOME"
mkdir -p "$BUILD_HOME/$REPO_ROOT_SUBDIR"
mkdir -p "$BUILD_HOME/$WORKSPACE_ROOT_SUBDIR"
ln -sfn "$REPO_ROOT_SUBDIR" "$REPO_ROOT"
ln -sfn "$WORKSPACE_ROOT_SUBDIR" "$WORKSPACE_ROOT"

shell() {
    if [[ "$1" == "--dry-run" ]] ; then
        echo ">>> (dry) running:" >&2
        echo "$2" >&2
        return
    fi
    echo ">>> running" >&2
    echo "$1" >&2
    ( eval "$1" ; )
}

# clone sources
cd "$REPO_ROOT"
if [[ -f ".repo-init-done" ]] && ! $REFRESH_SOURCE ; then
    notice "repo already initialized, exiting"
    exit 0
fi

if $DRY_RUN && [[ -f ".repo-init-done" ]] ; then
    dry_run_arg="--dry-run"
else
    dry_run_arg=
fi

# We can't dry run, since we need the sources
dry_run_arg=

shell $dry_run_arg "repo init -u \"$MANIFEST_URL\" -b \"$MANIFEST_BRANCH\" -m \"$MANIFEST\""
for d in $(repo forall -c 'echo $REPO_PATH' 2>/dev/null) ; do
    [[ -d "$d" ]] || continue
    shell $dry_run_arg "
        set -e ;
        cd \"$d\"
        git rebase --abort >/dev/null 2>&1 || :
        git am --abort >/dev/null 2>&1 || :
        git clean -d -f
        git checkout .
    "
done
with_default_retries shell $dry_run_arg "repo sync --force-sync --force-remove-dirty -j4"
# prevent "stx build prepare" from doing another "repo sync"
shell $dry_run_arg "touch .repo-init-done"

