#!/bin/bash

source $(dirname "$0")/lib/job_utils.sh || exit 1
source $(dirname "$0")/lib/publish_utils.sh || exit 1

load_build_env || exit 1

if $DRY_RUN ; then
    bail "DRY_RUN=false is not supported, bailing out"
fi

TEMP_DIR="$BUILD_OUTPUT_HOME/tmp"
mkdir -p "$TEMP_DIR" || exit 1

checksum_files_list_file="$TEMP_DIR/published_iso_checksum_files"
find_checksum_files "${PUBLISH_SUBDIR}/outputs/std/iso" \
                    "${PUBLISH_SUBDIR}/outputs/rt/iso" \
                    "${PUBLISH_SUBDIR}/outputs/iso" \
    >"$checksum_files_list_file" || exit 1

dst_dir="${PUBLISH_DIR}/outputs/iso"
checksum_file="$dst_dir/$CHECKSUMS_FILENAME"
regfile_list_file="$TEMP_DIR/iso_files"

src_dir="$BUILD_OUTPUT_HOME/localdisk/deploy"
abs_src_dir="$(readlink -e "$src_dir")" || continue

rm -rf --one-file-system "$dst_dir" || exit 1
rm -f "$regile_list_file"

find "$src_dir" -xtype f -name 'starlingx*.iso' | sort | {
    declare -a reg_files
    while read iso_filename ; do
        for filename in "$iso_filename" "${iso_filename%.iso}.sig" ; do
            real_filename="$(readlink -e "$filename")" || continue
            if ! in_list "$real_filename" "${reg_files[@]}" ; then
                mkdir -p "$dst_dir" || exit 1
                publish_file "$real_filename" "$dst_dir" "$checksum_files_list_file" >>"$checksum_file" || exit 1
                reg_files+=("$real_filename")
            fi
            if [[ -L "$filename" ]] ; then
                dst_link_target="$(basename "$real_filename")"
                dst_link="$dst_dir/$(basename "$filename")"
                ln -s -f -n "$dst_link_target" "$dst_link" || exit 1
                echo "SYMLINK $dst_link" || exit 1
            fi
        done
    done
}
check_pipe_status || exit 1


