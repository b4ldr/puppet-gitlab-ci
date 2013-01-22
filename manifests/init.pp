# Install gitlab-ci
class gitlab_ci {
    if $::osfamily == 'RedHat' and $::operatingsystem != 'Fedora' {
        include epel
    }

    user { 'gitlab_ci':
        ensure  => present,
        comment => 'GitLab CI',
        system  => true,
    }

    package { 'redis':
        ensure  => installed,
    }
}