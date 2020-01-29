# Root this-is-the-sr-server config file. Fans out to different kinds of service
# we operate.

# git_root: The root URL to access the SR git repositories
class sr_site( $git_root ) {
  $competitor_services = hiera('competitor_services')
  $volunteer_services = hiera('volunteer_services')

  # Default PATH
  Exec {
    path => [ '/usr/bin' ],
  }

  # Directory for 'installed flags' for various flavours of data. When some
  # piece of data is loaded from backup/wherever into a database, files here
  # act as a guard against data being reloaded.
  file { '/usr/local/var':
    ensure => directory,
    owner => 'root',
    group => 'root',
    mode => '0755',
  }

  file { '/usr/local/var/sr':
    ensure => directory,
    owner => 'root',
    group => 'root',
    mode => '0700',
    require => File['/usr/local/var'],
  }

  # Choose speedy yum mirrors
  package { 'yum-plugin-fastestmirror':
    ensure => latest,
  }

  # Fedora no longer ships with a cron installed by default, I chose one at random
  package { 'cronie':
    ensure => latest,
  } ->
  service { 'crond':
    ensure => running,
  }

  exec { 'setenforce 0':
    path      => '/usr/sbin:/usr/bin',
    onlyif    => 'test $(getenforce) = "Enforcing"',
    provider  => shell,
  }

  augeas { 'disable selinux':
    context => '/files/etc/selinux/config',
    changes => ['set SELINUX disabled'],
  }

  # The bee
  include bee

  # Various common dependencies
  package {[
    'PyYAML',
    'python3-ldap',
  ]:
    ensure => present,
  }

  # Monitoring
  class { 'monitoring':
    git_root => $git_root,
  }

  class { 'sr_site::firewall':
    require => File['/usr/local/var/sr'],
  }

  class { 'python':
    manage_gunicorn => false,
    virtualenv      => present,
  }

  include sr_site::login
  include sr_site::meta

  if $competitor_services or $volunteer_services {
    class { 'sr_site::mysql':
      require => File['/usr/local/var/sr'],
    }
  }

  if $competitor_services {
    package { 'python-ldap':
      ensure => present,
    }
    package { 'python-unidecode':
      name      => 'unidecode',
      ensure    => present,
      provider  => 'pip',
    }
    package { 'python3-unidecode':
      name      => 'unidecode',
      ensure    => present,
      provider  => 'pip3',
    }

    class { 'sr_site::openldap':
      require => File['/usr/local/var/sr'],
    }

    # Installs a userman instance into /root. Technically for sysadmins
    # (volunteers), but only useful on boxes which have the LDAP on them.
    class { 'sr_site::userman':
      git_root => $git_root,
    }
  }

  if $volunteer_services {
    # Anonymous git access
    include gitdaemon

    class { 'sr_site::trac':
      git_root => $git_root,
      require => [File['/usr/local/var/sr'],
      Class['www']],
    }

    if $subversion_enabled {
      include sr_site::subversion
    }

    class { 'sr_site::git':
      git_root => $git_root,
    }
  }

  # Web stuff
  class { 'www':
    git_root => $git_root,
    require => File['/usr/local/var/sr'],
  }

  class { 'sr_site::backup':
    git_root => $git_root,
  }

  # Sanity stuff
  package { "rsyslog":
    ensure => latest,
  }

  service { 'rsyslog':
    ensure  => running,
    require => Package['rsyslog'],
  }

  package { ['htop', 'lsof', 'nano', 'nmap-ncat', 'screen']:
    ensure => latest,
  }

  file {'/etc/systemd/journald.conf':
    ensure => present,
    owner => 'root',
    group => 'root',
    mode => '0755',
    source => 'puppet:///modules/sr_site/journald.conf'
  }
}
