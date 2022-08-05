// vim: syn=groovy

library "common@${params.JENKINS_SCRIPTS_BRANCH}"

setBuildDescr()

pipeline {
    agent any
    options {
        timestamps()
    }
    parameters {
        string (
            name: 'MASTER_JOB_NAME'
        )
        string (
            name: 'MASTER_BUILD_NUMBER'
        )
        string (
            name: 'JENKINS_SCRIPTS_BRANCH'
        )
        string (
            name: 'BUILD_HOME'
        )
        string (
            name: 'TIMESTAMP'
        )
        string (
            name: 'PUBLISH_TIMESTAMP'
        )
        booleanParam (
            name: 'DRY_RUN'
        )
    }
    stages {
        stage ("archive-jenkins-logs") {
            steps { script {
                if (params.BUILD_HOME) {
                    final String build_conf = "${params.BUILD_HOME}/build.conf"
                    final String jenkins_api_credentials_id = sh (returnStdout: true,
                        script: """#!/bin/bash
                            set -e
                            if [[ -f "${build_conf}" ]] ; then
                                source "${build_conf}"
                                echo -n "\${JENKINS_API_CREDENTIALS_ID}"
                            fi
                        """
                    );
                    if (!jenkins_api_credentials_id) {
                        error ("JENKINS_API_CREDENTIALS_ID is not defined in ${build_conf}")
                    }
                    withEnv (["BUILD_HOME=${params.BUILD_HOME}"]) {
                        withCredentials ([usernameColonPassword (
                                             credentialsId: jenkins_api_credentials_id,
                                             variable: 'JENKINS_API_USERPASS')]) {
                            sh "${Constants.SCRIPTS_DIR}/publish-logs.sh"
                        }
                    }
                }
            } }
        }
    }
}
