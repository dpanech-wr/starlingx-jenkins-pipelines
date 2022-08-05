# bash

if [[ -z "$__LOG_UTILS_INCLUDED" ]] ; then
__LOG_UTILS_INCLUDED=1


#
# Usage: dump_stack [FRAME_OFFSET]
#
dump_stack() {
    local -i index
    local -i max_index="${#BASH_SOURCE[@]}"
    local -a line_numbers=($LINENO "${BASH_LINENO[@]}")
    for ((index=${1:-0}; index < max_index; ++index)) {
        echo "  at ${BASH_SOURCE[$index]} line ${line_numbers[$index]}"
    }
}

#
# Usage: print_log [OPTIONS...] LINES...
#
# Print a log message -- LINES... followed by RAW_LINES...
#
#  --dump-stack         include stack trace in output
#  --frame-offset=N     frame offset for stack trace (default: 0)
#  --prefix=PREFIX      include PREFIX in front of each LINE
#  --location           include caller function name in front of each LINE
#  --epilog=EPILOG      include EPILOG in output
#  --loud               be loud
#  -i,--increment-frame-offset
#                       add one to frame-offset (additive)
#
__print_log_usage() {
    local func="${FUNCNAME[1]}"
    echo "
################################################################################
ERROR: ${func}: invalid syntax
$(dump_stack 2)

Usage: $func [OPTIONS...] LINES... RAW_LINES...
See ${BASH_SOURCE[0]} near line ${LINENO} for more info.
################################################################################
"
}
print_log() {
    (
        set +x
        local -i frame_offset=1
        local -i frame_offset_offset=0
        local -i dump_stack_frame_offset
        local -i dump_stack=0
        local line_prefix
        local epilog
        local -i include_location=0
        local loud_prefix loud_suffix
        local loud_line_prefix

        # parse command line
        local opts
        local -a rsync_opts
        opts="$(\
            getopt -n "${FUNCNAME[0]}" -o "+i" \
                -l dump-stack \
                -l frame-offset: \
                -l increment-frame-offset \
                -l prefix: \
                -l location\
                -l epilog: \
                -l loud \
                -- "$@"
        )"
        if [[ $? -ne 0 ]] ; then
            __print_log_usage
            exit 1
        fi
        eval set -- "${opts}"
        while true ; do
            case "$1" in
            --dump-stack)
                dump_stack=1
                shift
                ;;
            --frame-offset)
                frame_offset="$2"
                shift 2
                ;;
            -i | --increment-frame-offset)
                let ++frame_offset_offset
                shift
                ;;
            --prefix)
                line_prefix="$2"
                shift 2
                ;;
            --location)
                include_location=1
                shift
                ;;
            --epilog)
                epilog="$2"
                shift 2
                ;;
            --loud)
                local nl=$'\n'
                loud_line_prefix=$'### '
                loud_prefix="${nl}${nl}${loud_line_prefix}${nl}"
                loud_suffix="${loud_line_prefix}${nl}${nl}"
                shift
                ;;
            --)
                shift
                break
                ;;
            -*)
                __print_log_usage
                exit 1
                ;;
            *)
                break
                ;;
            esac
        done
        if [[ "$#" -lt 1 ]] ; then
            __print_log_usage
            exit 1
        fi

        let frame_offset+=frame_offset_offset

        local location
        if [[ $include_location -eq 1 ]] ; then
            local -i funcname_index=$frame_offset
            location="${FUNCNAME[$funcname_index]}: "
        fi

        echo -n "$loud_prefix"
        while [[ "$#" -gt 0 ]] ; do
            local line="$1" ; shift || true
            echo "${location}${loud_line_prefix}${line_prefix}${line}"
        done
        shift || true
        if [[ $dump_stack -eq 1 ]] ; then
            let dump_stack_frame_offset=frame_offset+1
            dump_stack $dump_stack_frame_offset
        fi
        if [[ -n "$epilog" ]] ; then
            echo -n "$epilog"
        fi
        echo -n "$loud_suffix"
    ) >&2
}

fi # include guard
