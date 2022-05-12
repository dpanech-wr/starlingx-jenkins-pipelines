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
            name: 'BUILD_RT'
        )
    }
    stages {
        stage ("download-prerequisites") {
            steps {
                sh ("${Constants.SCRIPTS_DIR}/download-prerequisites.sh")
            }
        }
    }
    post {
        always {
            notAborted {
                sh ("${Constants.SCRIPTS_DIR}/archive-prerequisites.sh")
            }
        }
        cleanup {
            cleanupPartJob()
        }
    }
}
