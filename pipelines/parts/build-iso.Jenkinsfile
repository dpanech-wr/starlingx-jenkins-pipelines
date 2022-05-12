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
        booleanParam (
            name: 'BUILD_ISO'
        )
    }
    stages {
        stage ("build-iso") {
            steps {
                sh ("${Constants.SCRIPTS_DIR}/build-iso.sh")
            }
        }
        stage ("sign-iso") {
            steps {
                sh ("${Constants.SCRIPTS_DIR}/sign-iso.sh")
            }
        }
    }
    post {
        always {
            notAborted {
                sh ("${Constants.SCRIPTS_DIR}/archive-iso.sh")
            }
        }
        cleanup {
            cleanupPartJob()
        }
    }
}
