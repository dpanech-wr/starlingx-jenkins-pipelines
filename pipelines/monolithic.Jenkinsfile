// vim: syn=groovy

library "common@${params.JENKINS_SCRIPTS_BRANCH}"

def parseProps(text) {
    def x = {}
    for (line in text.split (/\n+/)) {
        if (line.matches (/\s*(?:#.*)?#/)) {
            continue
        }
        parts = line.split ("=", 2)
        key = parts[0]
        value = parts[1]
        x."${key}" = value
    }
    return x
}

def loadEnv() {
    def data = {}
    data.NEED_BUILD = false
    ws(params.BUILD_HOME) {
        if (fileExists ("NEED_BUILD")) {
            data.NEED_BUILD = true
        }
    }
    final String configText = sh (script: "${Constants.SCRIPTS_DIR}/print-config.sh", returnStdout: true)
    final props = parseProps (configText)
    data.BUILD_OUTPUT_HOME_URL = props.BUILD_OUTPUT_HOME_URL
    data.PUBLISH_URL = props.PUBLISH_URL
    return data
}

def PROPS = null
def IMG_PARAMS = null

def partJobName (name) {
    final String folder = env.JOB_NAME.replaceAll (/(.*\/).+$/, '$1');
    if (folder == env.JOB_NAME) {
        error "This job must be in a Jenkins folder!"
    }
    return "/" + folder + "parts/" + name
}

def runPart (name, params = []) {
    build job: partJobName (name), parameters: copyCurrentParams() + params
}

def printBuildFooter(final props) {
    if (props) {
        String msg = ""
        msg += "\n"
        msg += "========================================\n"
        msg += "\n"
        if (props.NEED_BUILD) {
            msg += "Build output:   ${props.BUILD_OUTPUT_HOME_URL}\n"
            if (props.PUBLISH_URL) {
                msg += "Publish output: ${props.PUBLISH_URL}\n"
            }
        }
        else {
            echo "*** NO CHANGES - BUILD NOT REQUIRED"
        }
        msg += "\n"
        msg += "========================================\n"
        msg += "\n"
        echo (msg)
    }
}

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
            name: 'BUILD_HOME'
        )
        string (
            name: 'TIMESTAMP',
        )
        string (
            name: 'PUBLISH_TIMESTAMP'
        )
        booleanParam (
            name: 'REBUILD_BUILDER_IMAGES'
        )
        booleanParam (
            name: 'REFRESH_SOURCE'
        )
        booleanParam (
            name: 'BUILD_PACKAGES'
        )
        string (
            name: 'BUILD_PACKAGES_LIST'
        )
        booleanParam (
            name: 'BUILD_ISO'
        )
        booleanParam (
            name: 'BUILD_RT'
        )
        booleanParam (
            name: 'DRY_RUN'
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
            name: 'FORCE_BUILD'
        )
        booleanParam (
            name: 'FORCE_BUILD_WHEELS'
        )
        string (
            name: 'DOCKER_IMAGE_LIST'
        )
        booleanParam (
            name: 'BUILD_DOCKER_IMAGES'
        )
        booleanParam (
            name: 'PUSH_DOCKER_IMAGES'
        )
        booleanParam (
            name: 'BUILD_HELM_CHARTS'
        )
        booleanParam (
            name: 'IMPORT_BUILD'
        )
        string (
            name: 'IMPORT_BUILD_DIR'
        )
        booleanParam (
            name: 'USE_DOCKER_CACHE',
        )
        string (
            name: 'JENKINS_SCRIPTS_BRANCH'
        )

    }
    stages {
        stage('INIT') {
            steps {
                script {
                    runPart ("init-env")
                    runPart ("stop-containers")
                    runPart ("clone-source")
                    runPart ("create-changelog")
                    PROPS = loadEnv()
                    if (!PROPS.NEED_BUILD) {
                        println "*** NO CHANGES, BUILD NOT REQUIRED ***"
                    }
                    IMG_PARAMS = [ string (name: 'BUILD_STREAM', value: 'stable') ]
                }
            }
        }
        stage('X0') {
            when { expression { PROPS.NEED_BUILD } }
            stages {
                stage('PREPARE') {
                    steps {
                        runPart ("clean-build")
                        runPart ("configure-build")
                        runPart ("start-containers")
                        runPart ("docker-login")
                    }
                }
                stage('DOWNLOAD') {
                    steps {
                        runPart ("download-prerequisites")
                    }
                }
                stage('PACKAGES') {
                    when { expression { params.BUILD_PACKAGES } }
                    steps {
                        runPart ("build-packages")
                        runPart ("publish-packages")
                    }
                }
                stage('X1') { parallel {
                    stage('ISO') {
                        when { expression { params.BUILD_ISO } }
                        steps {
                            runPart ("build-iso")
                            runPart ("publish-iso")
                        }
                    } // stage('ISO')
                    stage('IMAGES') {
                        when { expression { params.BUILD_DOCKER_IMAGES } }
                        stages {
                            stage('IMAGES:wheels') { steps { script {
                                runPart ("build-wheels", IMG_PARAMS)
                                runPart ("publish-wheels", IMG_PARAMS)
                            } } }
                            stage('IMAGES:base') { steps { script {
                                runPart ("build-docker-base", IMG_PARAMS)
                                runPart ("build-docker-images", IMG_PARAMS)
                            } } }
                            stage('IMAGES:images') { steps { script {
                                runPart ("build-docker-images", IMG_PARAMS)
                                runPart ("publish-docker-images", IMG_PARAMS)
                            } } }
                            stage('IMAGES:helm') {
                                when { expression { params.BUILD_HELM_CHARTS } }
                                steps { script {
                                    runPart ("build-helm-charts", IMG_PARAMS)
                                    runPart ("publish-helm-charts", IMG_PARAMS)
                                } }
                            }
                        }
                    } // stage('IMAGES')
                } }// stage('X1')
            } // stages

            post {
                always {
                    runPart ("stop-containers")
                    notAborted {
                        runPart ("archive-misc")
                    }
                }
                success {
                    sh ("BUILD_STATUS=success ${Constants.SCRIPTS_DIR}/record-build-status.sh")
                }
                unsuccessful {
                    sh ("BUILD_STATUS=fail ${Constants.SCRIPTS_DIR}/record-build-status.sh")
                }
            }
        } // stage X0
    } // stages

    post {
        cleanup {
            saveCurrentJenkinsBuildInfo()
            notAborted {
                runPart ("publish-logs")
            }
            printBuildFooter (PROPS)
        }
    }
}

