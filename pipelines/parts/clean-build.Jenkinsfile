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
            name: 'DRY_RUN'
        )
        string (
            name: 'BUILD_PACKAGES_LIST'
        )
        booleanParam (
            name: 'CLEAN_PACKAGES'
        )
        booleanParam (
            name: 'CLEAN_ISO'
        )
        booleanParam (
            name: 'CLEAN_REPOMGR'
        )
        booleanParam (
            name: 'CLEAN_DOWNLOADS'
        )
        booleanParam (
            name: 'CLEAN_DOCKER'
        )
        booleanParam (
            name: 'IMPORT_BUILD'
        )
        string (
            name: 'IMPORT_BUILD_DIR'
        )
    }
    stages {
        stage ("clean-build") {
            steps {
                sh ("${Constants.SCRIPTS_DIR}/clean-build.sh")
            }
        }
    }
    post {
        cleanup {
            cleanupPartJob()
        }
    }
}
