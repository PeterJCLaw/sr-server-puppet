# phpBB, the popular and featureful forum software.

class www::phpbb ( $git_root, $root_dir ) {
  # MySQL database configuration
  $forum_db_name = 'phpbb_sr2020'
  $forum_user = hiera('phpbb_sql_user')
  $forum_pw = hiera('phpbb_sql_pw')

  $host_ip_from_within_container = '172.17.0.1'

  file { $root_dir:
    ensure  => directory,
    mode    => '0755',
  }

  # Create the MySQL db for the forum
  mysql::db { $forum_db_name:
    user => $forum_user,
    password => $forum_pw,
    host => 'localhost',
    grant => ['all'],
  }

  # Load the database data from backup, if it hasn't already.
  exec { 'pop_forum_db':
    command => "mysql -u ${forum_user} --password='${forum_pw}' ${forum_db_name} < /srv/secrets/mysql/${forum_db_name}.db && touch /usr/local/var/sr/forum_installed",
    provider => 'shell',
    creates => '/usr/local/var/sr/forum_installed',
    require => Mysql::Db[$forum_db_name],
  }

  # Maintain permissions on the config file, and template it. Contains SQL
  # connection gunge.
  $config_file = "${root_dir}/config.php"
  file { $config_file:
    ensure => present,
    content => template('www/forum_config.php.erb'),
    require => File[$root_dir],
  }

  # The style we want
  archive { 'phpbb-prosilver_se-style':
    ensure        => present,
    url           => 'https://www.phpbb.com/customise/db/download/160251',
    extension     => 'zip',
    digest_string => 'bd17b840431d12ef335d73755be787f0',
    digest_type   => 'md5',
    target        => "${root_dir}/styles",
    # where it downloads the file to, also where it puts the .md5 file
    src_target    => $root_dir,
    require       => File[$root_dir],
  }

  file { "${root_dir}/ext":
    ensure  => directory,
    mode    => '0755',
    require => File[$root_dir],
  }

  # Our custom extensions
  $extensions_dir = "${root_dir}/ext/sr"
  file { $extensions_dir:
    ensure  => directory,
    mode    => '0755',
    require => File["${root_dir}/ext"],
  }

  vcsrepo { "${extensions_dir}/etc":
    ensure    => present,
    provider  => git,
    source    => "${git_root}/phpbb-ext-sr-etc.git",
    revision  => 'origin/master',
    require   => File[$extensions_dir],
  }

  # Extension for slack integration
  file { "${root_dir}/ext/TheH":
    ensure  => directory,
    mode    => '0755',
    require => File["${root_dir}/ext"],
  }

  vcsrepo { "${root_dir}/ext/TheH/entropy":
    ensure    => present,
    provider  => git,
    source    => 'https://github.com/haivala/phpBB-Entropy-Extension',
    revision  => '61390529da8e49a7aa306dcf33046659e1bbc0f6', # pin so upgrades are explicit
    require   => File["${root_dir}/ext/TheH"],
  }

  # Directory for storing forum attachments.
  $attachments_dir = "${root_dir}/files"
  file { $attachments_dir:
    ensure => directory,
    mode => '2770',
    require => File[$root_dir],
  }

  # Some form of forum page cache
  file { "${root_dir}/cache":
    ensure => directory,
    mode => '2770',
    require => File[$root_dir],
  }

  # Not the foggiest, but this is how it was on optimus, so this is configured
  # thus here too.
  file { "${root_dir}/store":
    ensure => directory,
    mode => '2770',
    require => File[$root_dir],
  }

  vcsrepo { "${root_dir}/python-port-forward":
    ensure    => present,
    provider  => git,
    source    => 'https://github.com/cgx027/python-port-forward',
    revision  => 'dc6657b28d52091d5b9909b32c243fdeb82a9059',
  } ->
  file { "${root_dir}/python-port-forward/port-forward.config":
    content  => template('www/port-forward.config.erb'),
  }

  sr_site::systemd_service { 'phpbb-port-forward':
    desc    => 'Forwards ports from the host for access from within the PHPBB Docker container.',
    dir     => "${root_dir}/python-port-forward",
    user    => 'root',
    command => "/usr/bin/python port-forward.py",
    subs    => [
      File["${root_dir}/python-port-forward/port-forward.config"],
      Vcsrepo["${root_dir}/python-port-forward"],
    ]
  }

  yumrepo { 'docker':
    descr     => 'Docker CE Stable - $basearch',
    ensure    => present,
    baseurl   => 'https://download.docker.com/linux/fedora/$releasever/$basearch/stable',
    gpgcheck  => true,
    gpgkey    => 'https://download.docker.com/linux/fedora/gpg',
  } ->

  # exec { 'add docker repo':
  #   command => 'dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo',
  #   creates => '/etc/yum.repos.d/docker-ce.repo',
  # }

  class { 'docker':
    use_upstream_package_source => false,
    # service_overrides_template  => false,
    # docker_ce_package_name      => 'docker',
    # bip             => '192.168.58.0/24',
    # fixed_cidr      => '192.168.58.4/32',
    # default_gateway => '192.168.58.1',
  }

  docker::image { 'bitnami/phpbb':
    # TODO: use a more recent tag once all set up & working
    image_tag => '3.2.3',
  }

  docker::run { 'phpbb':
    image   => 'bitnami/phpbb',
    # Connection port 8080 outside the container (i.e: from nginx) to port 80
    # inside the container (i.e: the apache there running the forum)
    ports   => '8080:80',
    env     => [
      "MARIADB_HOST=${host_ip_from_within_container}",
      "PHPBB_DATABASE_NAME=${forum_db_name}",
      "PHPBB_DATABASE_USER=${forum_user}",
      "PHPBB_DATABASE_PASSWORD=${forum_pw}",
    ],
    require => Vcsrepo["${root_dir}/python-port-forward"],
  }
}
