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
        booleanParam (
            name: 'PUSH_DOCKER_IMAGES',
        )
        booleanParam (
            name: 'USE_DOCKER_CACHE',
        )
        string (
            name: 'BUILD_STREAM'
        )
    }
    stages {
        stage ("build-docker-base") {
            steps {
                sh ("${Constants.SCRIPTS_DIR}/build-docker-base.sh")
            }
        }
    }
    post {
        cleanup {
            cleanupPartJob (logLabel: params.BUILD_STREAM)
        }
    }
}
