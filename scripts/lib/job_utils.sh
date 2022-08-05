: ${LOADBUILD_ROOTS:="/localdisk/loadbuild:/home/localdisk/loadbuild"}
: ${DESIGNER_ROOTS:="/localdisk/designer:/home/localdisk/designer"}

source "${BASH_SOURCE[0]%/*}"/utils.sh || return 1
source "${BASH_SOURCE[0]%/*}"/log_utils.sh || return 1

# Top-level source directory of jenkins scripts repo
TOP_SCRIPTS_DIR=$(readlink -f "${BASH_SOURCE[0]%/*}"/..)

# Library scripts dir
LIB_DIR="$TOP_SCRIPTS_DIR/lib"

# Scripts dir
SCRIPTS_DIR="$TOP_SCRIPTS_DIR/scripts"

# When true produce less noise
#QUIET=false

# Python 3.x executable
: ${PYTHON3:=python3}

# docker images
SAFE_RSYNC_DOCKER_IMG="servercontainers/rsync:3.1.3"
COREUTILS_DOCKER_IMG="debian:bullseye-20220509"
APT_UTILS_DOCKER_IMG="debian:bullseye-20220509"

notice() {
    ( set +x ; print_log -i --loud "$@" ; )
}

info() {
    ( set +x ; print_log -i --prefix ">>> " "$@" ; )
}

error() {
    ( set +x ; print_log -i --loud --dump-stack --location --prefix "ERROR: " "$@" ; )
}

warn() {
    ( set +x; print_log -i --prefix "WARNING: " --location "$@" ; )
}

die() {
    ( set +x ; print_log -i --loud --dump-stack --location --prefix "ERROR: " "$@" ; )
    exit 1
}

bail() {
    ( set +x ; print_log -i --prefix ">>> " "$@" ; )
    exit 0
}

trim() {
    echo "$@" | sed -r -e 's/^\s+//' -e 's/\s+$//'
}

maybe_run() {
    local cmd
    local sep=''
    local arg
    for arg in "$@" ; do
        cmd+="$sep" ; sep=' '
        cmd+="$(printf '%q' "$arg")"
    done
    if $DRY_RUN ; then
        echo "running (dry run): $cmd"
    else
        echo "running: $cmd"
        "$@"
    fi
}

#
# Usage: declare_env NAME [DFLT]
#
# Make sure the specified env var is defined & non-empty,
# otherwise it to a default value.
# Trim and export it in either case.
declare_env() {
    local var="$1"
    local dflt="$2"

    # trim it
    local val="$(trim "${!var}")"

    # set to default
    if [[ -z "$val" ]] ; then
        val="$(trim "$dflt")"
        declare -g -x "$var=$val"
        return
    fi

    # export it
    declare -g -x "$var"
}

#
# Usage: require_env NAME [DFLT]
#
# Same as declare_env, but fail & exit if the var is empty
require_env() {
    local var="$1" ; shift || :
    declare_env "$var" "$@"
    [[ -n "${!var}" ]] || die "required variable \"$var\" is not set"
}

#
# Usage: require_file FILENAME
#
# Make sure file exists and is readable; die otherwise
#
require_file() {
    : <"$1" || die "$1: couldn't open file file reading"
}

__set_common_vars() {
    require_env BUILD_HOME
    require_env TIMESTAMP
    declare_env PUBLISH_TIMESTAMP "$TIMESTAMP"
    declare_env DRY_RUN

    # Set dry-run options
    if [[ "$DRY_RUN" != "false" ]] ; then
        DRY_RUN="true"
        DRY_RUN_ARG="--dry-run"
    else
        DRY_RUN="false"
        DRY_RUN_ARG=""
    fi

    export PATH="/usr/local/bin:$PATH"
}

__set_build_vars() {

    require_env BUILD_USER
    require_env PROJECT
    require_env BUILD_HOME
    require_env BUILD_OUTPUT_ROOT
    require_env BUILD_OUTPUT_ROOT_URL
    require_env TIMESTAMP
    require_env PUBLISH_ROOT
    require_env PUBLISH_ROOT_URL
    require_env PUBLISH_TIMESTAMP

    # Set a few additional globals
    REPO_ROOT_SUBDIR=localdisk/designer/$BUILD_USER/$PROJECT
    WORKSPACE_ROOT_SUBDIR=localdisk/loadbuild/$BUILD_USER/$PROJECT
    REPO_ROOT="$BUILD_HOME/repo"
    WORKSPACE_ROOT="$BUILD_HOME/workspace"
    USER_ID=$(id -u $BUILD_USER) || exit 1
    BUILD_OUTPUT_HOME="$BUILD_OUTPUT_ROOT/$TIMESTAMP"
    BUILD_OUTPUT_HOME_URL="$BUILD_OUTPUT_ROOT_URL/$TIMESTAMP"

    # publish vars
    PUBLISH_DIR="${PUBLISH_ROOT}/${PUBLISH_TIMESTAMP}${PUBLISH_SUBDIR:+/$PUBLISH_SUBDIR}"
    PUBLISH_URL="${PUBLISH_ROOT_URL}/${PUBLISH_TIMESTAMP}${PUBLISH_SUBDIR:+/$PUBLISH_SUBDIR}"

    # parallel
    if [[ -n "$PARALLEL_CMD" && "${PARALLEL_CMD_JOBS:-0}" -gt 0 ]] ; then
        PARALLEL="$PARALLEL_CMD -j ${PARALLEL_CMD_JOBS}"
    else
        PARALLEL=
    fi
}

__started_by_jenkins() {
    [[ -n "$JENKINS_HOME" ]]
}

#
# Usage: load_build_config
#
# Source $BUILD_HOME/build.conf and set a few common globals
#
load_build_config() {
    __set_common_vars || exit 1
    source "$BUILD_HOME/build.conf" || exit 1
    __set_build_vars || exit 1
}

#
# Usage: load_build_env
#
# Load $BUILD_HOME/build.conf and source stx tools env script
#
load_build_env() {
    __set_common_vars || exit 1
    require_file "$BUILD_HOME/build.conf" || exit 1
    source "$BUILD_HOME/source_me.sh" || exit 1
    __set_build_vars || exit 1
}

# Usage: stx_docker_cmd [--dry-run] SHELL_SNIPPET
stx_docker_cmd() {
    local dry_run=0
    if [[ "$1" == "--dry-run" ]] ; then
        dry_run=1
        shift
    fi
    if [[ "$QUIET" != "true" ]] ; then
        echo ">>> running builder pod command:" >&2
        echo "$1" | sed -r 's/^/\t/' >&2
    fi
    if [[ "$dry_run" -ne 1 ]] ; then
        local -a args
        if __started_by_jenkins ; then
            args+=("--no-tty")
        fi
        stx -d shell "${args[@]}" -c "$1"
    fi
}

# Usage: docker_login REGISTRY
# Login to docker in builder pod
docker_login() {
    local reg="$1"
    local login_arg
    if [[ "$reg" != "docker.io" ]] ; then
        login_arg="$reg"
    fi
    stx_docker_cmd "docker login $login_arg </dev/null"
}

#
# Usage: parse_docker_registry REGISTRY[/NAMESPACE]
#
# Parse a registry name and print the registry and the namespace
# separated by a space. Print an error and return non-zero
# if the registry string is invalid.
#
# Examples:
#   parse_docker_registry foo               # ERROR
#   parse_docker_registry foo/bar           # ERROR
#   parse_docker_registry foo.com/bar///baz # foo.com bar/baz
#
parse_docker_registry() {
    local spec="$1"
    local registry namespace
    # up to 1st slash
    registry="$(echo "$spec" | sed 's!/.*!!' || :)"
    # remove double-shashes & extract everything past the 1st slash
    namespace="$(echo "$spec" | sed -e 's!//*!/!g' | sed -n -e 's!^[^/]*/\(.*\)!\1!p' || :)"
    # registry must contain a dot or a colon to distinguish it from a local namespace
    if ! { echo "$registry" | grep -q -E "[.:]" ; } ||
       ! { echo "$registry" | grep -q -E "^[a-zA-Z0-9._-]+(:[0-9]{1,5})?$" ; } ; then
        error "invalid docker registry spec \"$spec\""
        return 1
    fi
    echo $registry $namespace
}

__get_protected_dirs() {
    [[ -n "$USER" ]] || die "USER not set"
    [[ -n "$PROJECT" ]] || die "PROJECT not set"

    local dir
    for dir in $(echo "$DESIGNER_ROOTS" "$LOADBUILD_ROOTS" | sed 's/:/ /g') ; do
        echo "$dir:ro"
        echo "$dir/$USER/$PROJECT"
    done
}

#
# Usage: __ensure_dirs_within_protected_set PROTECTED_DIRS... -- DIRS...
# Make sure wach DIR equals or starts with any of PROTECTED_DIRS
#
__ensure_dirs_within_protected_set() {
    local -a protected_dirs
    while [[ "$#" -gt 0 && "$1" != "--" ]] ; do
        protected_dirs+=("$1")
        dir="$1"
        shift
    done
    shift || true

    while [[ "$#" -gt 0 ]] ; do
        local dir="$1" ; shift || true
        if ! echo "$dir" | grep -q '^/' ; then
            error -i "$dir: directories must be absolute"
            return 1
        fi
        # check if $dir under any of $protected_dirs
        local safe=0
        local parent_dir
        for protected_dir in "${protected_dirs[@]}" ; do
            protected_dir="${protected_dir%%:*}"
            if [[ "$dir" == "$protected_dir" || "${dir#$protected_dir/}" != "${dir}" ]] ; then
                safe=1
                break
            fi
        done
        if [[ $safe != 1 ]] ; then
            error -i "attempted to operate on an unsafe directory \"$dir\""
            return 1
        fi
    done
}

#
# Usage: __ensure_dir_not_blacklisted_for_writing [--skip-missing] PATH...
#
__ensure_dir_not_blacklisted_for_writing() {
    local -a blacklist_dir_list=(
        "/"
    )
    local -a blacklist_prefix_list=(
        "/usr/"
        "/etc/"
        "/var/"
        "/run/"
        "/proc/"
        "/sys/"
        "/boot/"
        "/dev/"
        "/media/"
        "/mnt/"
        "/proc/"
        "/net/"
        "/sys/"
    )
    local skip_missing=0
    if [[ "$1" == "--skip-missing" ]] ; then
        skip_missing=1
        shift
    fi
    local dir
    for dir in "$@" ; do
        local abs_dir
        if ! abs_dir="$(readlink -f "$dir")" ; then
            if [[ $skip_missing -eq 1 ]] ; then
                continue
            fi
            error -i "$dir: does not exist or is not readable"
            return 1
        fi
        #if [[ ! -w "$abs_dir" ]] ; then
        #    error -i "$dir: not writable"
        #    return 1
        #fi

        if in_list "$abs_dir" "${blacklist_dir_list}" || \
            starts_with "$abs_dir" "${blacklist_prefix_list}" ; then
            error -i "$dir: is blacklisted for writing"
            return 1
        fi
    done
}

#
# Usage: __safe_docker_run [--dry-run] PROTECTED_DIRS... -- <DOCKER RUN OPTIONS>
#
__safe_docker_run() {
    local loc="${BASH_SOURCE[0]}(${BASH_LINENO[0]}): ${FUNCNAME[0]}: "
    local dry_run=0
    local dry_run_prefix
    if [[ "$1" == "--dry-run" ]] ; then
        dry_run=1
        dry_run_prefix="(dry_run) "
        shift || true
    fi

    # construct mount options
    local -a mount_opts
    while [[ "$#" -gt 0 && "$1" != "--" ]] ; do
        local dir="$1" ; shift
        local extra_mount_str=""
        if echo "$dir" | grep -q : ; then
            local opt
            local -a extra_mount_opts
            for opt in $(echo "$dir" | sed -e 's/.*://' -e 's/,/ /g') ; do
                if [[ "$opt" == "ro" ]] ; then
                    extra_mount_str+=",ro"
                    continue
                fi
                error -i "invalid mount option \"$opt\""
                return 1
            done
            dir="${dir%%:*}"
        fi
        mount_opts+=("--mount" "type=bind,src=$dir,dst=$dir""$extra_mount_str")
    done
    shift || true
    if [[ "$QUIET" != "true" ]] ; then
        echo ">>> ${dry_run_prefix}running: docker run ${mount_opts[@]} $@" >&2
    fi
    if [[ $dry_run -ne 1 ]] ; then
        local docker_opts=("-i")
        if [[ -t 0 ]] ; then
            docker_opts+=("-t")
        fi
        docker run "${docker_opts[@]}" "${mount_opts[@]}" "$@"
    fi

}

#
# Usage: safe_docker_run <DOCKER RUN OPTIONS>
# Run a docker container with safe/protected dirs mounted
#
safe_docker_run() {
    local -a protected_dirs
    local protected_dirs_str
    protected_dirs_str="$(__get_protected_dirs)" || return 1
    readarray -t protected_dirs <<<"$(echo -n "$protected_dirs_str")" || return 1
    __safe_docker_run "${protected_dirs[@]}" -- "$@"
}

#
# Usage:
#   safe_copy_dir [--exclude PATTERN ...]
#                 [--include PATTERN ...]
#                 [--delete]
#                 [--chown USER:GROUP]
#                 [--dry-run]
#                 [-v | --verbose]
#                 SRC_DIR... DST_DIR
#
safe_copy_dir() {
    local usage_msg="
Usage: ${FUNCNAME[0]} [OPTIONS...] SRC_DIR... DST_DIR
"
    # get protected dirs
    local -a protected_dirs
    local protected_dirs_str
    protected_dirs_str="$(__get_protected_dirs)" || return 1
    readarray -t protected_dirs <<<"$(echo -n "$protected_dirs_str")" || return 1

    # parse command line
    local opts
    local -a rsync_opts
    local dry_run_arg=
    opts=$(getopt -n "${FUNCNAME[0]}" -o "v" -l exclude:,include:,delete,chown:,dry-run,verbose -- "$@")
    [[ $? -eq 0 ]] || return 1
    eval set -- "${opts}"
    while true ; do
        case "$1" in
        --exclude)
            rsync_opts+=("--exclude" "$2")
            shift 2
            ;;
        --include)
            rsync_opts+=("--include" "$2")
            shift 2
            ;;
        --delete)
            rsync_opts+=("--delete-after")
            shift
            ;;
        --dry-run)
            dry_run_arg="--dry-run"
            shift
            ;;
        --chown)
            rsync_opts+=("--chown" "$2")
            shift 2
            ;;
        -v | --verbose)
            rsync_opts+=("--verbose")
            shift
            ;;
        --)
            shift
            break
            ;;
        -*)
            error --epilog="$usage_msg" "invalid options"
            return 1
            ;;
        *)
            break
            ;;
        esac
    done
    if [[ "$#" -lt 2 ]] ; then
        error --epilog="$usage_msg" "invalid options"
        return 1
    fi
    local dst_dir="${@:$#:1}"

    # make sure dirs start with a known prefix
    __ensure_dirs_within_protected_set "${protected_dirs[@]}" -- "$@" || return 1

    # make sure last destination dir is writeable
    __ensure_dir_not_blacklisted_for_writing "${dst_dir}"

    # run rsync in docker, filter out noisy greetings
    rsync_opts+=(--archive --devices --specials --hard-links --recursive --one-file-system)
    __safe_docker_run $dry_run_arg "${protected_dirs[@]}" -- --rm "$SAFE_RSYNC_DOCKER_IMG" rsync "${rsync_opts[@]}" "$@"
    if [[ ${PIPSTATUS[0]} -ne 0 ]] ; then
        error "failed to copy files"
        return 1
    fi

}

#
# Usage: safe_rm [OPTIONS...] PATHS
#
safe_rm() {
    local usage_msg="
Usage: ${FUNCNAME[0]} [OPTIONS...] PATHS...
     --dry-run
  -v,--verbose
"
    # get protected dirs
    local -a protected_dirs
    local protected_dirs_str
    protected_dirs_str="$(__get_protected_dirs)" || return 1
    readarray -t protected_dirs <<<"$(echo -n "$protected_dirs_str")" || return 1

    # parse command line
    local opts
    local -a rm_opts
    local -a rm_cmd=("rm")
    opts=$(getopt -n "${FUNCNAME[0]}" -o "v" -l dry-run,verbose -- "$@")
    [[ $? -eq 0 ]] || return 1
    eval set -- "${opts}"
    while true ; do
        case "$1" in
        --dry-run)
            rm_cmd=("echo" "(dry run)" "rm")
            shift
            ;;
        -v | --verbose)
            rm_opts+=("--verbose")
            shift
            ;;
        --)
            shift
            break
            ;;
        -*)
            error --epilog="$usage_msg" "invalid options"
            return 1
            ;;
        *)
            break
            ;;
        esac
    done
    if [[ "$#" -lt 1 ]] ; then
        error --epilog="$usage_msg" "invalid options"
        return 1
    fi

    __ensure_dirs_within_protected_set "${protected_dirs[@]}" -- "$@" || return 1
    __ensure_dir_not_blacklisted_for_writing --skip-missing "$@"

    # run rsync in docker
    rm_opts+=(--one-file-system --preserve-root --recursive --force)
    info "removing $*"
    if ! __safe_docker_run "${protected_dirs[@]}" -- --rm "$COREUTILS_DOCKER_IMG" "${rm_cmd[@]}" "${rm_opts[@]}" -- "$@" ; then
        error "failed to remove files"
        return 1
    fi

}

#
# Usage: safe_chown OPTIONS USER[:GROUP] PATHS...
safe_chown() {
    local usage_msg="
Usage: ${FUNCNAME[0]} [OPTIONS...] USER[:GROUP] PATHS...
     --dry-run
  -v,--verbose
  -R,--recursive
"
    # get protected dirs
    local -a protected_dirs
    local protected_dirs_str
    protected_dirs_str="$(__get_protected_dirs)" || return 1
    readarray -t protected_dirs <<<"$(echo -n "$protected_dirs_str")" || return 1

    # parse command line
    local cmd_args
    local dry_run_arg
    local -a cmd=("chown")
    opts=$(getopt -n "${FUNCNAME[0]}" -o "vR" -l dry-run,verbose,recursive -- "$@")
    [[ $? -eq 0 ]] || return 1
    eval set -- "${opts}"
    while true ; do
        case "$1" in
        --dry-run)
            dry_run_arg="--dry-run"
            shift
            ;;
        -v | --verbose)
            cmd_args+=("--verbose")
            shift
            ;;
        -R | --recursive)
            cmd_args+=("--recursive")
            shift
            ;;
        --)
            shift
            break
            ;;
        -*)
            error --epilog="$usage_msg" "invalid options"
            return 1
            ;;
        *)
            break
            ;;
        esac
    done
    if [[ "$#" -lt 2 ]] ; then
        error --epilog="$usage_msg" "invalid options"
        return 1
    fi
    local user_group="$1" ; shift

    __ensure_dirs_within_protected_set "${protected_dirs[@]}" -- "$@" || return 1
    __ensure_dir_not_blacklisted_for_writing --skip-missing "$@"

    # resolve USER:GROUP to UID:GID
    local uid_gid
    uid_gid=$(
        gid_suffix=
        user="${user_group%%:*}"
        if echo "$user_group" | grep -q ":" ; then
            group="${user_group#*:}"
            if [[ -n "$group" ]] ; then
                gid=$(getent "$group" | awk -F ':' '{print $3}')
                [[ -n "$gid" ]] || exit 1
            fi
            gid=$(id -g $user) || exit 1
            gid_suffix=":$gid"
        fi
        uid=$(id -u $user) || exit 1
        echo "${uid}${gid_suffix}"
    ) || {
        error "unable to resolve owner $user_group"
        return 1
    }

    if ! __safe_docker_run $dry_run_arg "${protected_dirs[@]}" -- --rm "$COREUTILS_DOCKER_IMG" \
                           "${cmd[@]}" "${cmd_args[@]}" -- "$uid_gid" "$@" ; then
        error "failed to change file ownership"
        return 1
    fi

}

# Usage: gen_deb_repo_meta_data [--origin=ORIGIN] [--label=LABEL] DIR
make_deb_repo() {
    local origin
    local label
    while [[ "$#" -gt 0 ]] ; do
        case "$1" in
            --origin=*)
                origin="${1#--origin=}"
                shift
                ;;
            --label=*)
                label="${1#--label=}"
                shift
                ;;
            *)
                break
                ;;
        esac
    done


    local dir="$1"
    (
        set -e
        cd "$dir"

        rm -f Packages Packages.gz
        (
            set -e
            dpkg-scanpackages -t deb -t deb --multiversion .
            dpkg-scanpackages -t deb -t udeb --multiversion .
        ) >Packages
        gzip -c Packages >Packages.gz

        __print_deb_release "$origin" "$label" >Release.tmp
        mv -f Release.tmp Release

        rm -f Packages
    )
}
__print_deb_release_checksums() {
    local section="$1"
    local checksum_prog="$2"
    local body
    local files="Packages"

    body="$(
        set -e
        for base in Packages ; do
            for file in "$base" "${base}.gz" "${base}.xz" "${base}.bz2" ; do
                if [[ -f "$file" ]] ; then
                    checksum=$($checksum_prog "$file" | awk '{print $1}' ; check_pipe_status) || exit 1
                    size=$(stat --format '%s' "$file") || exit 1
                    printf ' %s %16d %s\n' "$checksum" "$size" "$file"
                fi
            done
        done
    )" || return 1
    if [[ -n "$body" ]] ; then
        echo "${section}:"
        echo "${body}"
    fi
}
__print_deb_release() {
    local origin="$1"
    local label="$2"
    local now

    # Date: ...
    now="$(date --rfc-2822 --utc)" || return 1
    echo "Date: $now"

    # Origin: ...
    if [[ -n "$origin" ]] ; then
        echo "Origin: $origin"
    fi

    # Label: ...
    if [[ -n "$label" ]] ; then
        echo "Label: $label"
    fi

    # <checksums>
    __print_deb_release_checksums "MD5Sum"  "md5sum"    || return 1
    __print_deb_release_checksums "SHA1"    "sha1sum"   || return 1
    __print_deb_release_checksums "SHA256"  "sha256sum" || return 1
    __print_deb_release_checksums "SHA512"  "sha512sum" || return 1
}

#gen_deb_repo_meta_data() {
#    local dry_run=0
#    local dry_run_cmd
#    if [[ "$1" == "--dry-run" ]] ; then
#        dry_run=1 ; shift || true
#        dry_run_cmd="echo >>> (dry run): "
#    fi
#    local dir="$1"
#    __ensure_dir_not_blacklisted_for_writing "$dir"
#    $dry_run_cmd cp \
#        "$SCRIPTS_DIR/helpers/create-deb-meta-priv.sh" \
#        "$SCRIPTS_DIR/helpers/create-deb-meta.sh" \
#        "$dir/"
#    $dry_run_cmd chmod +x "$dir/create-deb-meta-priv.sh" "$dir/create-deb-meta-priv.sh"
#    local now
#    now="$(date -R)" || return 1
#    local -a docker_run=(
#        __safe_docker_run
#        --
#        --rm
#        --mount "type=bind,src=$dir,dst=$dir"
#        -w "$dir"
#        -e "__REALLY_RUN_ME=1"
#        -e "NOW=$now"
#        "$APT_UTILS_DOCKER_IMG"
#        /bin/bash
#        -c
#    )
#    local rv=0
#    $dry_run_cmd "${docker_run[@]}" "./create-deb-meta-priv.sh $(id -u) $(id -g)" || rv=1
#    $dry_run_cmd rm -f "$dir/create-deb-meta-priv.sh"
#    $dry_run_cmd rm -f "$dir/create-deb-meta.sh"
#    $dry_run_cmd rm -rf "$dir/cache"
#    if [[ $rv -ne 0 ]] ; then
#        error "failed to generate meta data in $dir"
#        return 1
#    fi
#    return 0
#}
