CHECKSUMS_FILENAME="StxChecksums"

publish_file() {
    local filename="$1"
    local dst_dir="$2"
    local published_checksum_files_list_file="$3"

    mkdir -p "$dst_dir" || exit 1

    local basename
    basename="${filename##*/}"

    local dst_file
    dst_file="$dst_dir/$basename"

    local checksum
    checksum=$(sha256sum "$filename" | awk '{print $1}' ; check_pipe_status) || exit 1

    # find an existing file in $combined_checksums_file that we can
    # hardlink to
    local link_created
    link_created=$(

        cat "$published_checksum_files_list_file" | {
            while read checksum_file ; do
                local checksum_dir
                checksum_dir="${checksum_file%/*}"

                link_created=$(
                    \grep "^$checksum " "$checksum_file" \
                    | while read x_checksum x_basename x_size x_mtime x_device x_inode x_path ; do

                        x_filename="$checksum_dir/$x_basename"
                        if [[ ! -f "$x_filename" || -z "$x_basename" || -z "$x_size" || -z "$x_mtime" || -z "$x_device" || -z "$x_inode" || -z "$x_path" ]] ; then
                            continue
                        fi

                        x_recheck_stat=$(stat --printf '%s %Y %d %i' "$x_filename") || continue
                        #echo ">>> $x_recheck_stat        $x_size $x_mtime $x_device $x_inode" >&2
                        [[ "$x_recheck_stat" == "$x_size $x_mtime $x_device $x_inode" ]] || continue
                        # try to link it
                        if \ln -f "$x_filename" "$dst_file" 2>&1 ; then
                            echo "LINK    $dst_file" >&2
                            echo "link_created"
                        fi
                        cat >/dev/null   # read and discard remaining lines to avoid SIGPIPE
                        exit 0
                    done
                ) || exit 1

                if [[ "$link_created" == "link_created" ]] ; then
                    echo "link_created"
                    cat >/dev/null   # read and discard remaining lines to avoid SIGPIPE
                    exit 0
                fi
            done
        }
        check_pipe_status || exit 1
    )
    check_pipe_status || exit 1

    # try to link source file to destination
    if [[ "$link_created" != "link_created" ]] ; then
        link_created=$(
            if \ln -f "$filename" "$dst_file" 2>&1 ; then
                echo "LINK    $dst_file" >&2
                echo "link_created"
            fi
        ) || exit 1
    fi

    # if all else fails, copy it
    if [[ "$link_created" != "link_created" ]] ; then
        \cp -f --preserve=mode,timestamps,xattr "$filename" "$dst_file" || exit 1
        echo "COPY    $dst_file" >&2
    fi

    # output published file info + source path
    local -a stat
    local size device inode mtime
    stat=($(stat --printf '%s %Y %d %i' "$dst_file")) || exit 1
    size="${stat[0]}"
    mtime="${stat[1]}"
    device="${stat[2]}"
    inode="${stat[3]}"

    echo "$checksum $basename $size $mtime $device $inode $filename"
}

find_publish_dirs() {
    find "$PUBLISH_ROOT" -mindepth 1 -maxdepth 1 \
                         -type d \
                         -name '[0-9][0-9][0-9][0-9]*' \
                         -not -name "$PUBLISH_TIMESTAMP"
}

find_checksum_files() {
    find_publish_dirs | while read dir ; do
        for subdir in "$@" ; do
            if [[ -d "$dir/$subdir" ]] ; then
                find "$dir/$subdir" -type f -name "$CHECKSUMS_FILENAME"
            fi
        done
    done
    check_pipe_status || exit 1
}
