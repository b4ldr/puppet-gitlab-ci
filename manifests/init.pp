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
    include rvm

    rvm_system_ruby { 'ruby-1.9.3':
        ensure      => 'present',
        default_use => true,
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

    exec { 'install-bundler':
        command => 'gem install bundler',
        user    => 'gitlab_ci',
        require => Rvm_system_ruby['ruby-1.9.3'],
    }

    exec { 'bundle --without development test':
        cwd     => '/home/gitlab_ci/gitlab-ci',
        user    => 'gitlab_ci',
        require => [Exec['install-bundler'], Vcsrepo['gitlab-ci'], Package['mysql-devel']],
    }

    file { 'database.yml':
        path    => '/home/gitlab_ci/gitlab-ci/config/database.yml',
        content => template('gitlab_ci/database.yml.erb'),
        require => Vcsrepo['gitlab-ci'],
    }

    exec { 'bundle exec rake db:setup RAILS_ENV=production':
        require => File['database.yml'],
        cwd     => '/home/gitlab_ci/gitlab-ci',
    }
}