# Install gitlab-ci
class gitlab_ci {
    if $::osfamily == 'RedHat' and $::operatingsystem != 'Fedora' {
        include epel
    }

    include gitlab_ci::db

    user { 'gitlab_ci':
        ensure  => present,
        comment => 'GitLab CI',
        system  => true,
    }

    package { 'redis':
        ensure  => installed,
    }
}