#!/bin/bash

set -e
source $(dirname "$0")/lib/job_utils.sh

require_env JENKINS_API_USERPASS

load_build_env

# Remove TTY codes from a log file
sanitize_log() {
    # See https://en.wikipedia.org/wiki/ANSI_escape_code#CSI_(Control_Sequence_Introducer)_sequences
    sed -r -e $'s#\033\\[[0-9:;<=>?]*[ !"#$%&\047()*+,./-]*[]@A-Z\\^_`a-z{|}~[]##g' -e 's#\r$##g' -e 's#\r#\n#g'
}

# This file contains JOB_NAME,BUILD_NUMBER,BUILD_URL,LABEL, one per line
if [[ -f "$BUILD_HOME/jenkins/builds.txt" ]] ; then
    log_dir="${PUBLISH_DIR}/logs"
    grep -v -E -e '^\s*(#.*)?*$' "$BUILD_HOME/jenkins/builds.txt" | {
        FAILED=0
        while IFS="," read job_name build_number build_url log_label ; do
            if [[ -n "$job_name" && -n "${build_number}" ]] ; then
                job_base_name="${job_name##*/}"
                log_file="by-build-number/${job_base_name}-${build_number}.log.txt"
                if [[ -n "$log_label" ]] ; then
                    log_link="${job_base_name}-${log_label}.log.txt"
                else
                    log_link="${job_base_name}.log.txt"
                fi
                # download log from jenkins if it doesn't exist
                if [[ -f "${log_dir}/${log_file}" ]] ; then
                    info "skipping ${log_dir}/${log_file} (file exists)"
                    continue
                fi
                info "downloading jenkins logs for $job_name #$build_number"
                mkdir -p "${log_dir}"
                mkdir -p "${log_dir}/by-build-number"
                log_url="${build_url}/consoleText"
                curl --fail --silent --show-error --location -u "$JENKINS_API_USERPASS" "${log_url}" \
                    | sanitize_log \
                    >"${log_dir}/${log_file}.tmp"
                if ! check_pipe_status ; then
                    FAILED=1
                    rm -f "${log_dir}/${log_file}.tmp"
                    continue
                fi
                mv "${log_dir}/${log_file}.tmp" "${log_dir}/${log_file}"
                ln -sfn "${log_file}" "${log_dir}/${log_link}"
            fi
        done
        [[ $FAILED -eq 0 ]] || exit 1
    }
fi
