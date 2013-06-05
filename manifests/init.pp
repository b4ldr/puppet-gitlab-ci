# Install gitlab-ci
class gitlab_ci(
    $db_username    = 'gitlab_ci',
    $db_password    = 'gitlab_ci',
) {
    if $::osfamily == 'RedHat' and $::operatingsystem != 'Fedora' {
        include epel
    }

    include nginx

    # TODO: Pass db params
    include gitlab_ci::db
    include gitlab_ci::redis
    include gitlab_ci::ruby

    user { 'gitlab_ci':
        ensure      => present,
        comment     => 'GitLab CI',
        system      => true,
        managehome  => true,
    }

    vcsrepo { 'gitlab-ci':
        ensure      => latest,
        path        => '/home/gitlab_ci/gitlab-ci',
        provider    => git,
        source      => 'https://github.com/gitlabhq/gitlab-ci.git',
        revision    => '2-2-stable',
        owner       => 'gitlab_ci',
        group       => 'gitlab_ci',
        require     => User['gitlab_ci'],
    }

    if !defined(Package['mysql-devel']) {
        package {'mysql-devel':
            ensure  => installed,
        }
    }

    if !defined(Package['git']) {
        package {'git':
            ensure  => installed,
        }
    }

    exec { 'install-bundle':
        command     => 'gem install bundler',
        path        => '/usr/local/bin',
        creates     => '/usr/bin/bundle',
        logoutput   => on_failure,
        require     => Class['gitlab_ci::ruby'],
    }

    exec { 'install-gitlab-ci':
        command     => 'bundle --without development test --deployment',
        cwd         => '/home/gitlab_ci/gitlab-ci',
        user        => 'gitlab_ci',
        path        => '/usr/bin',
        require     => [
            Class['gitlab_ci::ruby'],
            Vcsrepo['gitlab-ci'],
            Package['mysql-devel'],
            Exec['install-bundle'],
        ],
        creates     => '/home/gitlab_ci/gitlab-ci/.bundle/config',
        logoutput   => on_failure,
    }

    file { 'database.yml':
        path    => '/home/gitlab_ci/gitlab-ci/config/database.yml',
        content => template('gitlab_ci/database.yml.erb'),
        require => Vcsrepo['gitlab-ci'],
    }

    exec { 'bundle exec rake db:setup RAILS_ENV=production':
        cwd         => '/home/gitlab_ci/gitlab-ci',
        path        => '/usr/bin',
        before      => Service['gitlab_ci'],
        refreshonly => true,
        subscribe   => File['database.yml'],
        require     => Exec['install-gitlab-ci'],
    }

    file { 'schedule.rb':
        path    => '/home/gitlab_ci/gitlab-ci/config/schedule.rb',
        ensure  => file,
        require => Vcsrepo['gitlab-ci'],
    }

    exec { 'bundle exec whenever -w RAILS_ENV=production':
        require => Vcsrepo['gitlab-ci'],
        cwd     => '/home/gitlab_ci/gitlab-ci',
        path        => '/usr/bin',
        refreshonly => true,
        subscribe   => File['schedule.rb'],
    }

    file { 'gitlab-ci-init':
        path    => '/etc/init.d/gitlab_ci',
        source  => '/home/gitlab_ci/gitlab-ci/lib/support/init.d/gitlab_ci',
        owner   => 'root',
        group   => 'root',
        mode    => '755',
        require => Vcsrepo['gitlab-ci'],
    }

    service { 'gitlab_ci':
        ensure  => running,
        enable  => true,
        require => File['gitlab-ci-init'],
    }

    nginx::resource::upstream { 'gitlab_ci':
        ensure  => present,
        members => [
            'unix:/home/gitlab_ci/gitlab-ci/tmp/sockets/gitlab-ci.socket',
        ]
    }

    nginx::resource::vhost { "$fqdn":
        ensure      => present,
        www_root    => '/home/gitlab_ci/gitlab-ci/public',
        try_files   => '$uri $uri/index.html $uri.html @gitlab_ci',
    }

    nginx::resource::location { "@gitlab_ci":
        location    => '@gitlab_ci',
        proxy       => 'http://gitlab_ci',
        vhost       => "$fqdn",
    }
}