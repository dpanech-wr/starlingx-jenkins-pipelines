#
# Copyright (c) 2022 Wind River Systems, Inc.
#
# SPDX-License-Identifier: Apache-2.0
#

FD_SHA=0
FD_NAME=1
FD_INODE=2
FD_PATH=3

fu_debug () {
    >&2 echo "DEBUG: ${1}"
}

fu_error () {
    >&2 echo "ERROR: ${1}"
}

get_file_data_from_path () {
    local path="${1}"
    local sha=""
    sha="$(sha256sum "${path}" | cut -d ' ' -f 1; return ${PIPESTATUS[0]})"
    if [ $? -ne 0 ]; then
        return 1
    fi
    echo "$sha $(basename ${path}) $(stat --format=%i ${path}) ${path}"
}

get_file_data_from_dir () {
    local directory="${1}"
    local list_file="${2}"

    local d
    local line
    local fields

    for d in $(find $directory -type d | grep -v 'repodata'); do
        sha256sum $d/*.deb $d/*.rpm $d/*.tar $d/*.tgz $d/*.gz $d/*.bz2 $d/*.xz 2> /dev/null | \
        while read line; do
            fields=( $(echo $line) )
            echo "${fields[0]} $(basename ${fields[1]})  $(stat --format=%i ${fields[1]}) ${fields[1]}"
        done
    done > ${list_file}.unsorted
    sort ${list_file}.unsorted > ${list_file}
    \rm -f ${list_file}.unsorted
}

is_merge_candidate () {
    local array1=( ${1} )
    local array2=( ${2} )

    fu_debug "is_merge_candidate ${1}"
    fu_debug "                vs ${2}"
    if [ "${array1[$FD_SHA]}" != "${array2[$FD_SHA]}" ]; then
        fu_debug "shas differ"
        return 1
    elif [ "${array1[$FD_NAME]}" != "${array2[$FD_NAME]}" ]; then
        fu_debug "names differ"
        return 1
    elif [ "${array1[$FD_INODE]}" = "${array2[$FD_INODE]}" ]; then
        fu_debug "inodes already the same"
        return 1
    elif [ "${array1[$FD_FPATH]}" = "${array2[$FD_PATH]}" ]; then
        fu_debug "paths already the same"
        return 1
    fi

    fu_debug "merge candidates:"
    fu_debug "   ${array1[$FD_PATH]}"
    fu_debug "   ${array2[$FD_PATH]}"

    return 0
}


cp_or_link () {
    local src_file="${1}"
    local dest_dir="${2}"
    shift 2
    local lst_files=( "${@}" )
    local lst_file
    local src_name
    local lnk_line
    local src_line
    local lnk_array=()
    local src_array=()

    if [ ! -d "${dest_dir}" ]; then
        fu_error "destination directory '${dest_dir}' not found"
        return 1
    fi

    src_name=$(basename ${src_file})
    src_line="$(get_file_data_from_path "${src_file}")" || return 1
    src_array=( ${src_line} )

    if [ -f "${dest_dir}/${src_name}" ]; then
        lnk_line="$(get_file_data_from_path "${dest_dir}/${src_name}")" || return 1
        lnk_array=( ${lnk_line} )
        # echo "src_line=${src_line}"
        # echo "lnk_line=${lnk_line}"
        if [ "${lnk_array[$FD_SHA]}" == "${src_array[$FD_SHA]}" ]; then
            echo "Already have ${src_name}"
            return 0
        fi
        fu_error "destination file '${dest_dir}/${src_name}' already exists"
        return 1
    fi


    for lst_file in "${lst_files[@]}"; do
        fu_debug "grep '${src_name}' in '${lst_file}'"
        grep "${src_name}" "${lst_file}" | \
        while read lnk_line; do
            if is_merge_candidate "$lnk_line" "$src_line" "${merge}" ; then
                lnk_array=( ${lnk_line} )
                fu_debug "ln ${lnk_array[$FD_PATH]} ${dest_dir}/${src_name}"
                \ln ${lnk_array[$FD_PATH]} ${dest_dir}/${src_name}
                if [ $? -ne 0 ]; then
                    fu_error "ln ${lnk_array[$FD_PATH]} ${dest_dir}/${src_name}"
                    return 0
                fi
                return 1
            fi
        done || return 0
    done

    fu_debug "cp $src_file ${dest_dir}/"
    \cp $src_file ${dest_dir}/
}

__make_deb_repo () {
    local root_dir="${1}"

    pushd "${root_dir}" || return 1
    # FIXME: Release file not valid
    dpkg-scanpackages . /dev/null > Release
    dpkg-scanpackages . /dev/null | gzip -9c > Packages.gz
    popd
}
