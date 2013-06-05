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
        revision    => '2-1-stable',
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

    # TODO: Throws error that it can't find bundler. Have to manually install with gem install bundler as gitlab_ci user.
    # TODO: Remove rvm paths so that this works when ruby version changes
    exec { 'bundle --without development test':
        cwd         => '/home/gitlab_ci/gitlab-ci',
        user        => 'gitlab_ci',
        require     => [Class['gitlab_ci::ruby'], Vcsrepo['gitlab-ci'], Package['mysql-devel']],
        path        => '/usr/local/rvm/gems/ruby-1.9.3-p429/bin:/usr/local/rvm/gems/ruby-1.9.3-p429@global/bin:/usr/local/rvm/rubies/ruby-1.9.3-p429/bin:/usr/local/rvm/bin:/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/sbin',
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
        path        => '/usr/local/rvm/gems/ruby-1.9.3-p429/bin:/usr/local/rvm/gems/ruby-1.9.3-p429@global/bin:/usr/local/rvm/rubies/ruby-1.9.3-p429/bin:/usr/local/rvm/bin:/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/sbin',
        before      => Service['gitlab_ci'],
        refreshonly => true,
        subscribe   => File['database.yml'],
    }

    file { 'schedule.rb':
        path    => '/home/gitlab_ci/gitlab-ci/config/schedule.rb',
        ensure  => file,
        require => Vcsrepo['gitlab-ci'],
    }

    exec { 'bundle exec whenever -w RAILS_ENV=production':
        require => Vcsrepo['gitlab-ci'],
        cwd     => '/home/gitlab_ci/gitlab-ci',
        path    => '/usr/local/rvm/gems/ruby-1.9.3-p429/bin:/usr/local/rvm/gems/ruby-1.9.3-p429@global/bin:/usr/local/rvm/rubies/ruby-1.9.3-p429/bin:/usr/local/rvm/bin:/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/sbin',
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