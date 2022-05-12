def call() {
    return params.collect {
        if (it.value instanceof Boolean) {
            return booleanParam (name: it.key, value: it.value)
        }
        else if (it.value instanceof String) {
            return string (name: it.key, value: it.value)
        }
        else {
            error "unsupported parameter type: key=${it.key} type=${it.value.class}"
        }
    }
}

