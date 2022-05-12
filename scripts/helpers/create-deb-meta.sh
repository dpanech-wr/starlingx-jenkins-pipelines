#!/bin/bash

set -ex

gen() {
    apt-ftparchive \
        -o APT::FTPArchive::AlwaysStat=1 \
        -o CacheDir=cache \
        -o Packages::Extensions='[ .deb, .udeb ]' \
        "$@"
}

gen packages . >Packages
gzip -9 -c Packages >Packages.gz
gen release . >Release
sed -r -i 's#^(Date:\s*).*#\1'"$NOW"'#' Release
rm -f Packages
