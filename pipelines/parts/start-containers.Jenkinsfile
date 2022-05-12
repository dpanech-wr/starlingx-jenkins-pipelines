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
        booleanParam (
            name: 'REBUILD_BUILDER_IMAGES'
        )
        booleanParam (
            name: 'USE_DOCKER_CACHE'
        )
    }
    stages {
        stage ("start-containers") {
            steps {
                sh ("${Constants.SCRIPTS_DIR}/start-containers.sh")
            }
        }
    }
    post {
        cleanup {
            cleanupPartJob()
        }
    }
}
