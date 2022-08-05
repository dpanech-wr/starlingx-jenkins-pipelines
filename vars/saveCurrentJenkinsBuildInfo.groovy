def call(final args = [:]) {
    if (params.BUILD_HOME) {
        final String logLabel = args.logLabel ?: ''
        withEnv (["BUILD_HOME=${params.BUILD_HOME}",
                  "LOG_LABEL=${logLabel}"]) {
            sh """#!/bin/bash
                set -e
                if [[ -d "${BUILD_HOME}/jenkins" ]] ; then
                    echo ${JOB_NAME},${BUILD_NUMBER},${BUILD_URL},${logLabel} >>"${BUILD_HOME}/jenkins/builds.txt"
                fi
            """
        }
    }
}
