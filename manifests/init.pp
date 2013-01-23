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
        managehome => true,
    }

    vcsrepo { '/home/gitlab_ci/gitlab-ci':
        ensure      => latest,
        provider    => git,
        source      => 'https://github.com/gitlabhq/gitlab-ci.git',
        revision    => '2-0-stable',
        owner       => 'gitlab_ci',
        group       => 'gitlab_ci',
        require     => User['gitlab_ci'],
    }
}