#!/bin/bash

set -e
source $(dirname "$0")/lib/job_utils.sh

require_env BUILD_HOME
require_env PUSH_DOCKER_IMAGES
declare_env DOCKER_CONFIG_FILE

load_build_env

HOST_WORKSPACE="$BUILD_HOME/workspace"

# login not required
$PUSH_DOCKER_IMAGES || bail "PUSH_DOCKER_IMAGES=$PUSH_DOCKER_IMAGES, docker login not required"

# find registries that require a login
declare dummy
declare login_spec login_reg
declare -a login_repos
declare -A login_repos_hash
# for each registry that requires a login
for login_spec in $DOCKER_REGISTRY_PUSH_LOGIN_LIST ; do
    read login_reg dummy <<<$(parse_docker_registry "$login_spec")
    # check if we intend to push to it
    declare spec reg
    for spec in ${DOCKER_REGISTRY:-docker.io} $DOCKER_EXTRA_REGISTRY_PREFIX_LIST ; do
        read reg dummy <<<$(parse_docker_registry "$spec")
        if [[ "$reg" == "$login_reg" && -z "${login_repos_hash[$reg]}" ]] ; then
            login_repos_hash["$reg"]=1
            login_repos+=("$reg")
        fi
    done
done
unset dummy login_spec login_reg spec reg
unset login_repos_hash
[[ "${#login_repos[@]}" -gt 0 ]] || bail "no push registries requiring authentication defined, docker login not required"


#
# Merge usernames & passwords from $DOCKER_CONFIG_FILE into
# $HOME/.docker/config.json inside the builder pod
#
# {
#    "auths": {
#      "repo.org:port": {
#        "auth": "..."        # base64-encoded USERNAME:PASSWORD
#      },
#      ...
#    }
# }
#
if [[ -z "$DOCKER_CONFIG_FILE" ]] ; then
    DOCKER_CONFIG_FILE=~/.docker/config.json
elif [[ ! $DOCKER_CONFIG_FILE =~ ^/ ]] ; then
    DOCKER_CONFIG_FILE="$BUILD_HOME/$DOCKER_CONFIG_FILE"
fi
require_file "$DOCKER_CONFIG_FILE"

notice "updating \$HOME/.docker/config.json in builder pod"
mkdir -p "$HOST_WORKSPACE/tmp"
old_docker_config_file="$HOST_WORKSPACE/tmp/docker.config.json.old"
new_docker_config_file="$HOST_WORKSPACE/tmp/docker.config.json.new"
rm -f "$old_docker_config_file"

# download the existing config file from the pod
QUIET=true stx_docker_cmd "[[ -f \$HOME/.docker/config.json ]] && 'cp' \$HOME/.docker/config.json \$MY_WORKSPACE/tmp/docker.config.json.old || true"

# merge the "auths" from DOCKER_CONFIG_FILE into it
$PYTHON3 -c '
import sys, json
ref_auths = json.load (open (sys.argv[1])).get ("auths", {})
try:
    config = json.load (open (sys.argv[2]))
    config.setdefault ("auths", {}).update (ref_auths)
except FileNotFoundError:
    config = {
        "auths": ref_auths
    }
json.dump (config, open (sys.argv[3], "w"), indent = "\t")
' "$DOCKER_CONFIG_FILE" "$old_docker_config_file" "$new_docker_config_file"

# upload it back to the pod
if [[ ! -f "$old_docker_config_file" ]] || ! diff -q -u "$old_docker_config_file" "$new_docker_config_file" ; then
    QUIET=true stx_docker_cmd "mkdir -p \$HOME/.docker && 'cp' \$MY_WORKSPACE/tmp/docker.config.json.new \$HOME/.docker/config.json"
fi
rm -f $old_docker_config_file $new_docker_config_file

notice "logging in to remote repos"
for reg in "${login_repos[@]}" ; do
    docker_login "$reg"
done
