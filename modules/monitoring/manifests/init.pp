# Support for monitoring our server's activities

class monitoring ( $git_root ) {

# install generic nagios checks
  package { 'nagios-plugins-all':
    ensure => installed,
  }

  package { 'nagios-plugins-check-updates':
    ensure => installed,
  }

  package { 'perl-Nagios-Plugin':
    ensure => installed,
  }

  package { 'perl-Sort-Versions':
    ensure => installed,
  }

  package {'perl-Readonly':
    ensure => installed,
  }

# create a user to do the checking
  user { 'monitoring':
    ensure => present,
    comment => 'Monitoring User',
    shell => '/bin/bash',
    gid => 'users',
  }

  file { '/home/monitoring':
    ensure => directory,
    owner => 'monitoring',
    group => 'users',
    mode => '0700',
    require => User['monitoring']
  }

  file { '/home/monitoring/.ssh':
    ensure => directory,
    owner => 'monitoring',
    group => 'users',
    mode => '0700',
  }

  file { '/home/monitoring/.ssh/authorized_keys':
    ensure => present,
    owner => 'monitoring',
    group => 'users',
    mode => '0600',
    source => '/srv/secrets/login/monitoring_ssh_keys',
    require => File['/home/monitoring/.ssh'],
  }

  file { '/srv/monitoring':
    ensure => directory,
    owner => 'root',
    group => 'root',
    mode => '0755',
    require => User['monitoring']
  }

  vcsrepo { '/srv/monitoring':
    ensure => present,
    owner => 'root',
    group => 'root',
    provider => 'git',
    source => "${git_root}/server-monitoring.git",
    # TODO: why is this not 'origin/master'?
    revision => 'master',
    require => User['monitoring']
  }

}
