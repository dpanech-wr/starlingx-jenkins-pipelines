# bash

stx_docker_cmd() {
    echo '[[ -f ~/buildrc ]] && source ~/buildrc || : ; [[ -f ~/localrc ]] && source ~/localrc || : ; ' "$1" | stx control enter
}

