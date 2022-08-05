# bash

in_list() {
    local s="$1" ; shift || :
    while [[ "$#" -gt 0 ]] ; do
        if [[ "$s" == "$1" ]] ; then
            return 0
        fi
        shift
    done
    return 1
}

get_weekday() {
    local date
    if [[ "$#" -gt 0 ]] ; then
        date="${1:0:10}"
    else
        date="today"
    fi
    date --date="$date" '+%a' | tr 'A-Z' 'a-z'
    [[ ${PIPESTATUS[0]} -eq 0 ]]
}

normalize_weekdays() {
    local day
    for day in "$@" ; do
        day="${day,,}"
        case "$day" in
            sun|sunday)    day=sun ;;
            mon|monday)    day=mon ;;
            tue|tuesday)   day=tue ;;
            wed|wednesday) day=wed ;;
            thu|thursday)  day=thu ;;
            fri|friday)    day=fri ;;
            sat|saturday)  day=sat ;;
            *)
                echo "$FUNCNAME: invalid week day \`$day'" >&2
                return 1
                ;;
        esac
        echo -n "$day "
    done
    echo
}

require_env() {
    while [[ "$#" -gt 0 ]] ; do
        if [[ -z "${!1}" ]] ; then
            echo "${FUNCNAME[1]}: required env var \`$1' not set" >&2
            exit 1
        fi
        shift
    done
}

# Usage: starts_with STR PREFIX...
# Return true (0) if STR starts with any of PREFIX strings
starts_with() {
    local str="$1" ; shift || true
    while [[ "$#" -gt 0 ]] ; do
        prefix="$1" ; shift || true
        if [[ "${str#$prefix}" != "$str" ]] ; then
            return 0
        fi
    done
    return 1
}

check_pipe_status() {
    local -a pipestatus=(${PIPESTATUS[*]})
    local -i i
    for ((i=0; i<${#pipestatus[*]}; ++i)) ; do
        [[ "${pipestatus[$i]}" -eq 0 ]] || return 1
    done
    return 0
}
