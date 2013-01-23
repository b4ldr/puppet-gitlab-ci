# Install gitlab-ci
class gitlab_ci(
    $db_username    = 'gitlab_ci',
    $db_password    = 'gitlab_ci',
) {
    if $::osfamily == 'RedHat' and $::operatingsystem != 'Fedora' {
        include epel
    }

    # TODO: Pass db params
    include gitlab_ci::db
    include gitlab_ci::redis
    include nginx
    include rvm

    rvm_system_ruby { 'ruby-1.9.3':
        ensure      => 'present',
        default_use => true,
    }

    rvm_gem { 'ruby-1.9.3/bundler': 
        ensure      => present,
        require     => Rvm_system_ruby['ruby-1.9.3'],
    }

    rvm::system_user { gitlab_ci: }

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
        revision    => '2-0-stable',
        owner       => 'gitlab_ci',
        group       => 'gitlab_ci',
        require     => User['gitlab_ci'],
    }

    if !defined(Package['mysql-devel']) {
        package {'mysql-devel':
            ensure  => installed,
        }
    }
    
    # TODO: Throws error that it can't find bundler. Have to manually install with gem install bundler as gitlab_ci user.
    # TODO: Remove rvm paths so that this works when ruby version changes
    exec { 'bundle --without development test':
        cwd     => '/home/gitlab_ci/gitlab-ci',
        user    => 'gitlab_ci',
        require => [Rvm_gem['ruby-1.9.3/bundler'], Vcsrepo['gitlab-ci'], Package['mysql-devel']],
        path    => '/usr/local/rvm/gems/ruby-1.9.3-p374/bin:/usr/local/rvm/gems/ruby-1.9.3-p374@global/bin:/usr/local/rvm/rubies/ruby-1.9.3-p374/bin:/usr/local/rvm/bin:/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/sbin',
    }

    file { 'database.yml':
        path    => '/home/gitlab_ci/gitlab-ci/config/database.yml',
        content => template('gitlab_ci/database.yml.erb'),
        require => Vcsrepo['gitlab-ci'],
    }

    # TODO: Only need to run these execs once
    exec { 'bundle exec rake db:setup RAILS_ENV=production':
        require => File['database.yml'],
        cwd     => '/home/gitlab_ci/gitlab-ci',
        path    => '/usr/local/rvm/gems/ruby-1.9.3-p374/bin:/usr/local/rvm/gems/ruby-1.9.3-p374@global/bin:/usr/local/rvm/rubies/ruby-1.9.3-p374/bin:/usr/local/rvm/bin:/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/sbin',
        before  => Service['gitlab_ci'],
    }

    exec { 'bundle exec whenever -w RAILS_ENV=production':
        require => Vcsrepo['gitlab-ci'],
        cwd     => '/home/gitlab_ci/gitlab-ci',
        path    => '/usr/local/rvm/gems/ruby-1.9.3-p374/bin:/usr/local/rvm/gems/ruby-1.9.3-p374@global/bin:/usr/local/rvm/rubies/ruby-1.9.3-p374/bin:/usr/local/rvm/bin:/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/sbin',
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
}