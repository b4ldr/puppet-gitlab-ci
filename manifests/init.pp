# Install gitlab-ci
class gitlab_ci {
    user { 'gitlab_ci':
        ensure  => present,
        comment => 'GitLab CI',
        system  => true,
    }
}