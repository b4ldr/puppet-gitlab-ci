# Install gitlab-ci
class gitlab_ci {
    if $::osfamily == 'RedHat' and $::operatingsystem != 'Fedora' {
        include epel
    }

    include gitlab_ci::db
    include gitlab_ci::redis
    include ruby

    user { 'gitlab_ci':
        ensure  => present,
        comment => 'GitLab CI',
        system  => true,
    }
}