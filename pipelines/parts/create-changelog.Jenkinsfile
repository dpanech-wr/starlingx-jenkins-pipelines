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
    environment {
        PATH                       = "/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin"
        SCRIPTS_DIR                = "${WORKSPACE}/v3/scripts"
        BUILD_HOME                 = "${BUILD_HOME}"
        TIMESTAMP                  = "${TIMESTAMP}"
        FORCE_BUILD                = "${FORCE_BUILD}"
        BUILD_DOCKER_IMAGES_DEV    = "${BUILD_DOCKER_IMAGES_DEV}"
        BUILD_DOCKER_IMAGES_STABLE = "${BUILD_DOCKER_IMAGES_STABLE}"
    }
    stages {
        stage ("create-changelog") {
            steps {
                sh ("${SCRIPTS_DIR}/create-changelog.sh")
            }
        }
    }
    post {
        cleanup {
            cleanupPartJob()
        }
    }
}
