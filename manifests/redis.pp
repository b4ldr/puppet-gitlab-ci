class gitlab_ci::redis {
    package { 'redis':
        ensure  => installed,
    }
}