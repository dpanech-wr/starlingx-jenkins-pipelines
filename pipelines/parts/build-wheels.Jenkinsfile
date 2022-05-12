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
            name: 'USE_DOCKER_CACHE',
        )
        string (
            name: 'BUILD_STREAM'
        )
        string (
            name: 'DOCKER_IMAGE_LIST'
        )
        booleanParam (
            name: 'FORCE_BUILD_WHEELS'
        )
    }
    stages {
        stage ("build-wheels") {
            steps {
                sh ("${Constants.SCRIPTS_DIR}/build-wheels.sh")
            }
        }
    }
    post {
        always {
            notAborted {
                sh ("${Constants.SCRIPTS_DIR}/archive-wheels.sh")
            }
        }
        cleanup {
            cleanupPartJob (logLabel: params.BUILD_STREAM)
        }
    }
}
