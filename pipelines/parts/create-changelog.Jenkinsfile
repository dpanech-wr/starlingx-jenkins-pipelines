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
            name: 'FORCE_BUILD'
        )
        booleanParam (
            name: 'BUILD_DOCKER_IMAGES_DEV'
        )
        booleanParam (
            name: 'BUILD_DOCKER_IMAGES_STABLE'
        )
    }
    stages {
        stage ("create-changelog") {
            steps {
                sh ("${Constants.SCRIPTS_DIR}/create-changelog.sh")
            }
        }
    }
    post {
        cleanup {
            cleanupPartJob()
        }
    }
}
