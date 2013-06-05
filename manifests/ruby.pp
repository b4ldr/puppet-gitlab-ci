class gitlab_ci::ruby{
    class {'::ruby':
        provider => 'source',
        version  =>  '1.9.3-p429',
    }
}