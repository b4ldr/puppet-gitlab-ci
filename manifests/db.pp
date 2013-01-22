class gitlab_ci::db {
    include mysql::server

    mysql::db { 'gitlab_ci_production':
        user        => 'gitlab_ci',
        password    => 'gitlab_ci',
    }
}