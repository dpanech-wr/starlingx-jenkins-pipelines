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
        booleanParam (
            name: 'DRY_RUN'
        )
    }
    stages {
        stage ("build-helm-charts") {
            steps {
                sh ("${Constants.SCRIPTS_DIR}/build-helm-charts.sh")
            }
        }
    }
    post {
        always {
            notAborted {
                sh ("${Constants.SCRIPTS_DIR}/archive-helm-charts.sh")
            }
        }
        cleanup {
            cleanupPartJob()
        }
    }
}
