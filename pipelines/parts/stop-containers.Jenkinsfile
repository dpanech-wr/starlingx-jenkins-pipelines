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
            name: 'BUILD_HOME',
        )
        string (
            name: 'TIMESTAMP'
        )
        string (
            name: 'PUBLISH_TIMESTAMP'
        )
    }
    environment {
        PATH         = "/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin"
        SCRIPTS_DIR  = "${WORKSPACE}/v3/scripts"
        BUILD_HOME   = "${BUILD_HOME}"
        TIMESTAMP    = "${TIMESTAMP}"
    }
    stages {
        stage ("stop-containers") {
            steps {
                sh ("bash ${SCRIPTS_DIR}/stop-containers.sh")
            }
        }
    }
    post {
        cleanup {
            cleanupPartJob()
        }
    }
}
