# The IDE. Here be dragons.

class www::ide ( $git_root, $root_dir, $team_status_imgs_live_dir ) {
  $ide_repos_root = "${root_dir}/repos"
  $venv_dir = "${root_dir}/venv"

  # Checkout of cyanide, acts as backend and serves the frontend of the IDE.
  vcsrepo { $root_dir:
    ensure => present,
    provider => git,
    source => "${git_root}/srobo-ide.git",
    revision => 'origin/master',
    user => 'wwwcontent',
    # Depend explicitly on PHP here since it's declared at the level above
    require => Package['php', 'php-json', 'php-ldap'],
  }

  # Secret key for encrypting IDE cookies, protecting against users twiddling
  # with stored data.
  file { "${root_dir}/config/ide-key.key":
    ensure => present,
    owner => 'wwwcontent',
    group => 'apache',
    mode => '0640',
    content => hiera('ide_cookie_key'),
    require => Vcsrepo[$root_dir],
  }

  # Site-local configuration is stored in local.ini; assign some variables that
  # will be templated into it.
  $ide_key_file = "${root_dir}/config/ide-key.key"
  $team_status_dir = "${root_dir}/settings/team-status"
  $team_status_imgs_dir = "${root_dir}/uploads/team-status"
  $ide_ldap_pw = hiera('ide_ldap_user_pw')
  file { "${root_dir}/config/local.ini":
    ensure => present,
    owner => 'wwwcontent',
    group => 'apache',
    mode => '0640',
    content => template('www/ide_config.ini.erb'),
    require => [
      Vcsrepo[$root_dir],
      Ldapres['mentors'],
      Ldapres['ide-admin'],
    ],
  }

  # IDE ldap user has general read access to ou=groups,o=sr.
  $ide_user = hiera('ide_ldap_user_uid')
  ldapres { "uid=${ide_user},ou=users,o=sr":
    ensure => present,
    binddn => 'cn=Manager,o=sr',
    bindpw => hiera('ldap_manager_pw'),
    ldapserverhost => 'localhost',
    ldapserverport => '389',
    require => Class['sr_site::openldap'],
    objectclass => ['inetOrgPerson', 'uidObject', 'posixAccount'],
    uid => $ide_user,
    cn => 'IDE account',
    sn => 'IDE account',
    uidnumber => '2323',
    gidnumber => '1999', # srusers
    homedirectory => '/home/ide',
    userpassword => hiera('ide_ldap_user_ssha_pw'),
  }

  # Zips directory contains generated zips, unsuprisingly. To be writeable
  # by apache. (Was configured 02777 on optimus, so it is here)
  file { "${root_dir}/zips":
    ensure => directory,
    owner => 'wwwcontent',
    group => 'apache',
    mode => '2777',
    require => Vcsrepo[$root_dir],
  }

  # Settings dir, contains user config goo, as well as team-status. (Was
  # configured 02777 on optimus, so it is here).
  file { "${root_dir}/settings":
    ensure => directory,
    owner => 'wwwcontent',
    group => 'apache',
    mode => '2777',
    require => Vcsrepo[$root_dir],
  }

  # Directory for user repos; self explanatory.
  file { $ide_repos_root:
    ensure => directory,
    owner => 'wwwcontent',
    group => 'apache',
    mode => '2777',
    require => Vcsrepo[$root_dir],
  }

  # Notifications. Never used, to my knowledge.
  file { "${root_dir}/notifications":
    ensure => directory,
    owner => 'wwwcontent',
    group => 'apache',
    mode => '2777',
    require => Vcsrepo[$root_dir],
  }

  # Virtual environment for the syntax checker
  file { $venv_dir:
    ensure  => directory,
    owner   => 'wwwcontent',
    group   => 'apache',
    require => Vcsrepo[$root_dir],
  } ->
  file { "${venv_dir}/lint-requirements.txt":
    ensure  => file,
    source  => 'puppet:///modules/www/ide-lint-requirements.txt',
  } ~>
  python::virtualenv { $venv_dir:
    ensure          => present,
    ensure_venv_dir => false,
    owner           => 'wwwcontent',
    group           => 'apache',
    requirements    => "${venv_dir}/lint-requirements.txt",
    require         => Class['python'],
    virtualenv      => 'python -m virtualenv',
  }

  # Team Status dir. Contains post-reviewed team-status images
  # Warning: This folder may be outside the IDE tree!
  file { $team_status_imgs_live_dir :
    ensure => directory,
    owner => 'wwwcontent',
    group => 'apache',
    mode => '2777',
  }

  # Install team status images from backup.
  exec { 'team_status_install':
    user => 'root',
    command => "su -m apache -c 'cp -r /srv/secrets/team_status_images/* ${team_status_imgs_live_dir}'; touch /usr/local/var/sr/team_status_images_installed",
    creates => '/usr/local/var/sr/team_status_images_installed',
    require => File[$team_status_imgs_live_dir],
  }

  # Uploads dir. Contains un-reviewed team-status images
  file { "${root_dir}/uploads":
    ensure => directory,
    owner => 'wwwcontent',
    group => 'apache',
    mode => '2777',
    require => Vcsrepo[$root_dir],
  }

  # Web Cache. Used for the combined CSS & JS files.
  file { "${root_dir}/web/cache":
    ensure => directory,
    owner => 'wwwcontent',
    group => 'apache',
    mode => '2777',
    require => Vcsrepo[$root_dir],
  }

  # Remove old conf script
  file { "${ide_repos_root}/conf":
    ensure => absent,
  }

  # Remove old repack script
  file { "${ide_repos_root}/repack":
    ensure => absent,
  }

  # Team activity script
  file { "${ide_repos_root}/team-activity.py":
    ensure  => link,
    target  => "${root_dir}/scripts/team-activity.py",
  }

  define repos_admin_script($dir, $command) {
    file { "${dir}/${name}":
      ensure  => present,
      owner   => 'wwwcontent',
      group   => 'apache',
      mode    => '0754',
      # Uses ide_repos_root from the outer scope
      content => template('www/ide_repo_foreach.erb'),
    }
  }

  # All-repo integrity checking script for after crashes.
  www::ide::repos_admin_script { 'fsck':
    dir     => $ide_repos_root,
    command => 'git fsck',
  }

  # Script for repacking/gcing user repos
  www::ide::repos_admin_script { 'repack-aggressive':
    dir     => $ide_repos_root,
    command => 'git gc --aggressive -q',
  }

  # Script for gcing user repos in the general case
  $gc_script_name = 'gc-all'
  $gc_script = "${ide_repos_root}/${gc_script_name}"
  www::ide::repos_admin_script { $gc_script_name:
    dir     => $ide_repos_root,
    command => 'git gc -q',
  }

  # Install backed up IDE copy unless data is already installed. This is based
  # on the assumption that all IDE data is in {config/settings/notifications}.
  exec { 'ide_copy':
    command =>
         "cp -r /srv/secrets/ide/notifications/* ${root_dir}/notifications && \
          cp -r /srv/secrets/ide/repos/* ${ide_repos_root} && \
          cp -r /srv/secrets/ide/settings/* ${root_dir}/settings && \
          chown -R apache.apache ${ide_repos_root}/* && \
          chown -R apache.apache ${root_dir}/notifications/* && \
          chown -R apache.apache ${root_dir}/settings/* && \
          touch /usr/local/var/sr/ide_installed",
    provider => 'shell',
    creates => '/usr/local/var/sr/ide_installed',
    require => [File["${root_dir}/notifications"],File[ $ide_repos_root ]],
  }

  # Syslog configuration, using local2
  file { '/etc/rsyslog.d/ide.conf':
    ensure => present,
    owner => 'root',
    group => 'root',
    mode => '0644',
    source => 'puppet:///modules/www/ide-syslog.conf',
    notify => Service['rsyslog'],
    require => Package['rsyslog']
  }

  cron { 'ide-cron':
    command => 'curl --insecure https://localhost/ide/control.php/cron/cron',
    hour => '3',
    minute => '14',
    user => 'root',
    require => Vcsrepo[$root_dir],
  }

  # Run git-gc on the IDE repos on Sunday mornings
  cron { 'gc-ide-repos':
    command   => $gc_script,
    hour      => '4',
    minute    => '7',
    weekday   => '0',
    user      => 'apache',
    require   => File[$gc_script],
  }

  package{'zip':
    ensure => present,
  }

  # Install the wifi keys that get exported in robot.zip into /etc, for reading
  # by the IDE.
  # The creation of the /etc/sr directory could be somewhere better; that can
  # be improved at a later date.
  file { '/etc/sr':
    ensure => directory,
    owner => 'root',
    group => 'root',
    mode => '755',
  }

  file { '/etc/sr/wifi-keys.yaml':
    ensure => present,
    owner => 'wwwcontent',
    group => 'apache',
    mode => '440',
    source => "/srv/secrets/wifi-keys.yaml",
  }
}
