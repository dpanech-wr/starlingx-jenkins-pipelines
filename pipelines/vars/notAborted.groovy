def call (final callback) {
    if (currentBuild.result != 'ABORTED') {
        callback()
    }
}
