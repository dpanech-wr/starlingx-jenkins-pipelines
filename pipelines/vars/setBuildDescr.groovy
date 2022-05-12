def call() {
    if (params.MASTER_JOB_NAME) {
        final masterBuildName = params.MASTER_JOB_NAME + ' #' + params.MASTER_BUILD_NUMBER + ' - ' + params.TIMESTAMP
        currentBuild.description = masterBuildName
    }
}
