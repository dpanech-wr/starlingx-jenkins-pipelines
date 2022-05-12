# bash

: ${_GLOB_UTILS_TEST:=0}
: ${_GLOB_UTILS_LOW_NOISE:=1}

#
# Convert a glob pattern to a basic (grep/sed) regex.
#
# This function doesn't treat "/" and "." specially.
#
glob_to_basic_regex() {

    # disable "set -x" to reduce noise in jenkins jobs
    if (
            [[ "$_GLOB_UTILS_LOW_NOISE" == 1 ]] && \
            shopt -po xtrace | grep -q -- -o >/dev/null
       ) 2>/dev/null
    then
        : "$FUNCNAME: disabling debug trace"
        set +x
        local restore_xtrace=1
    else
        local restore_xtrace=0
    fi

    local len="${#1}"
    local i c c2
    local range_start range_len
    local neg_char
    local res
    for ((i=0; i<len; ++i)) ; do
        c="${1:$i:1}"

        # character range [...]
        if [[ "$c" == '[' ]] ; then
            # find end bracket
            range_len=""
            # check if its a negative range
            # negative ranges start with "!" in glob and "^" in regex
            let ++i
            neg_char=
            if [[ "${1:$i:1}" == '!' ]] ; then
                let ++i
                neg_char='^'
            fi
            # at this point i refers to the 1st char in range
            # range can't be empty, so we need to skip
            # this first char, then search for ']'
            range_start=$i
            for ((++i; i<len; ++i)) ; do
                if [[ "${1:$i:1}" == ']' ]] ; then
                    let range_len=i-range_start
                    break
                fi
            done
            # end bracket found: append the (possibly negative) range
            if [[ -n "$range_len" ]] ; then
                res+='['
                res+="$neg_char"
                res+="${1:$range_start:$range_len}"
                res+=']'
                let i=range_start+range_len
            # end bracket not found: append '\['
            else
                res+='\]'
            fi
            continue
        fi

        # Backslash is an escape char in glob, but not in basic regex,
        # except when followed by a meta character: * { etc
        # Surround next char with "[]"
        if [[ "$c" == '\' ]] ; then
            let ++i
            # backslash at end of string: append a literal '\'
            if [[ $i -ge $len ]] ; then
                c2='\'
            else
                c2="${1:$i:1}"
            fi
            # we can't use this method with '[^]'
            if [[ "$c2" != '^' ]] ; then
                res+="[$c2]"
                continue
            fi
            res+='\^'
            continue
        fi

        # Escape ^ as \^ -- can't use square brackets
        # because this is a negation character in ranges
        if [[ "$c" == '^' ]] ; then
            res+='\^'
            continue
        fi

        # Escape these using square brackets:
        #   $.      - have special meaning in regex
        #   /,!|#@  - these are not special, but are frequently
        #             used as separators in sed "s" command
        if [[ "$c" == '$' || "$c" == '.' ||
              "$c" == '/' || "$c" == ',' || "$c" == '!' ||
              "$c" == '|' || "$c" == '#' || "$c" == '@' ]] ; then
            res+="[$c]"
            continue
        fi

        # "?" => "."
        if [[ "$c" == '?' ]] ; then
            res+='.'
            continue
        fi

        # "*" => ".*"
        if [[ "$c" == '*' ]] ; then
            res+='.*'
            continue
        fi

        # anything else: append as is
        res+="$c"
    done
    echo "^${res}\$"
    if [[ "$restore_xtrace" == 1 ]] ; then
        set -x # debug output of this "set" is suppressed
        set -x # execute it again, this time with "-x" already on
        : "$FUNCNAME: restored debug trace"
    fi
}

# unit tests
if [[ "$_GLOB_UTILS_TEST" == 1 ]] ; then
    expect() {
        local glob="$1"
        local expected="$2"
        local actual
        actual="$(glob_to_basic_regex "$1")"
        if [[ "$actual" != "$expected" ]] ; then
            echo "${BASH_SOURCE}:${BASH_LINENO}: glob_to_basic_regex '$glob': expected '$expected' actual '$actual'" >&2
            exit 1
        fi
    }
    expect 'a[0-9]b'  '^a[0-9]b$'
    expect 'a[!0-9]b' '^a[^0-9]b$'
    expect 'a?b'      '^a.b$'
    expect 'a*b'      '^a.*b$'
    expect 'a\*b'     '^a[*]b$'
    expect 'a^b$c'    '^a\^b[$]c$'
    expect '/foo/*'   '^[/]foo[/].*$'
    expect 'a.b'      '^a[.]b$'
    expect 'a\[b'     '^a[[]b$'
    expect 'a[a-z]b[!A-Z]c[!0-9[]d!^' '^a[a-z]b[^A-Z]c[^0-9[]d[!]\^$'
    expect 'abc\'     '^abc[\]$'
    expect 'a\b'      '^a[b]$'
fi
