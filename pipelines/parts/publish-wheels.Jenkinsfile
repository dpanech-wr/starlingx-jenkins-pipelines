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
        string (
            name: 'BUILD_STREAM'
        )
    }
    stages {
        stage ("publish-wheels") {
            steps {
                sh ("${Constants.SCRIPTS_DIR}/publish-wheels.sh")
            }
        }
    }
    post {
        cleanup {
            cleanupPartJob (logLabel: params.BUILD_STREAM)
        }
    }
}
