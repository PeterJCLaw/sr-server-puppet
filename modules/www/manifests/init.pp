# Primary file for the www module - all this does is include other puppet files
# to configure portions of the website.

class www( $git_root ) {
  $competitor_services = hiera('competitor_services')
  $volunteer_services = hiera('volunteer_services')
  $web_root_dir = '/var/www/html'

  # many things rely on PHP
  package { ['php', 'php-cli', 'php-json', 'php-ldap', 'php-mysqlnd']:
    ensure => latest,
    notify => Service['httpd'],
  }

  class { 'www::httpd':
    web_root_dir => $web_root_dir,
  }

  class { 'www::nginx_rproxy':
    require => Class['www::httpd'],
  }

  # We shouldn't let apache own any web content, lest it be able to edit
  # content rather than just serve it. So, all web content that doesn't have
  # a more appropriate user gets owned by wwwcontent (with group=apache).
  user { 'wwwcontent':
    ensure => present,
    comment => 'Owner of all/most web content',
    shell => '/bin/sh',
    gid => 'apache',
    require => Package['httpd'],
  }

  file { '/etc/sr':
    ensure => directory,
    owner => 'root',
    group => 'root',
    mode => '755',
  }

  # Home dir needed so it can run cron jobs.
  file { '/home/wwwcontent':
    ensure  => directory,
    owner   => 'wwwcontent',
    group   => 'users',
    mode    => '0711',
    require => User['wwwcontent'],
  }

  file { $web_root_dir:
    ensure => directory,
    owner => 'wwwcontent',
    group => 'apache',
    mode => '644',
    require => [User['wwwcontent'], File['/var/www']],
  }

  file { "$web_root_dir/index.html":
    ensure  => present,
    owner   => 'wwwcontent',
    group   => 'apache',
    mode    => '644',
    content => "<h2>${::hostname}</h2>",
  }

  if $competitor_services {
    # Python 2.7.5 docs -- version match the python on the BBs
    class { 'www::python_docs':
      web_root_dir => $web_root_dir,
      version => '2.7.5',
      require => [User['wwwcontent'], File[$web_root_dir]],
    }

    # phpBB forum, at srobo.org/forum
    class { 'www::phpbb':
      git_root  => $git_root,
      root_dir  => '/var/www/phpbb',
      require   => User['wwwcontent'],
    }

    # The IDE, srobo.org/ide
    class { 'www::ide':
      git_root => $git_root,
      root_dir => "${web_root_dir}/ide",
      team_status_imgs_live_dir => "${web_root_dir}/team-images",
      development_target => lookup('ide_development_target'),
      require => [User['wwwcontent'], File[$web_root_dir]],
    }

    # A httpd server specifically for the IDE
    class { 'www::ide_httpd':
      git_root => $git_root,
      root_dir => "${web_root_dir}/ide",
      require => [User['wwwcontent'], File[$web_root_dir]],
    }

    # Code Submission Service for the Virtual Competition
    class { 'www::code_submitter':
      git_root => $git_root,
      root_dir => '/srv/code-submitter',
      require => User['wwwcontent'],
    }

    # Web facing user managment interface, srobo.org/userman
    class { 'www::nemesis':
      git_root => $git_root,
      root_dir => '/srv/nemesis',
      require => User['wwwcontent'],
    }

    class { 'www::teamgit':
      ide_root_dir => "${web_root_dir}/ide",
      require => Class['www::ide'],
    }

    # Ticket System
    class { 'www::tickets':
      git_root => $git_root,
      web_root_dir => $web_root_dir,
      require => [File[$web_root_dir], Class['sr_site::Openldap']],
    }

    # Media Consent System
    class { 'www::mediaconsent':
      git_root => $git_root,
      web_root_dir => $web_root_dir,
      require => [File[$web_root_dir], Class['sr_site::Openldap'], Class['www::tickets']],
    }
  }

  if $volunteer_services {
    # Voting scripts, at srobo.org/~voting/voting
    class { 'www::voting':
      git_root => $git_root,
      web_root_dir => $web_root_dir,
      require => User['wwwcontent'],
    }

    # Community guidelines
    class { 'www::community_guidelines':
      git_root => $git_root,
      web_root_dir => $web_root_dir,
      require => [User['wwwcontent'], File[$web_root_dir]],
    }

    # Volunteer Handbook
    class { 'www::volunteer_handbook':
      git_root => $git_root,
      web_root_dir => $web_root_dir,
      require => [User['wwwcontent'], File[$web_root_dir]],
    }

    # Piwik, for getting information about visitors, srobo.org/piwik
    class { 'www::piwik':
      git_root => $git_root,
      root_dir => "${web_root_dir}/piwik",
      require => [User['wwwcontent'], File[$web_root_dir]],
    }
  }
}
