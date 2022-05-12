#!/bin/bash

set -ex

: ${__REALLY_RUN_ME:?}

apt-get update
apt-get install apt-utils -y
chown "$1" .
groupadd --gid "$2" --non-unique "group-$2"
useradd --gid "$2" --uid "$1" --non-unique --no-create-home "user-$1"
/sbin/runuser "user-$1" -- ./create-deb-meta.sh

