# This adds a checkout of userman.git into the root user's home folder.
# While not entirely needed on the live server, it's very useful,
# especially on development badger instances

class sr_site::userman ( $git_root ) {
  # Checkout of userman's code.
  $root_dir = '/root/userman'
  vcsrepo { $root_dir:
    ensure    => present,
    provider  => git,
    source    => "${git_root}/userman.git",
    revision  => 'origin/master',
    owner     => 'root',
    group     => 'root',
    require   => Package['python3-pyyaml', 'python3-ldap', 'python3-unidecode'],
  }

  # local configuration is stored in local.ini
  $local_ini = "${root_dir}/sr/local.ini"
  $ldap_manager_pw = hiera('ldap_manager_pw')
  file { $local_ini:
    owner   => 'root',
    group   => 'root',
    mode    => '0600',
    content => template('sr_site/userman_srusers.ini.erb'),
    require => Vcsrepo[$root_dir],
  }

  # Configurate nemesis with the ability to send emails.
  $nemesis_mail_smtp = hiera('nemesis_mail_smtp')
  $nemesis_mail_user = hiera('nemesis_mail_user')
  $nemesis_mail_pw   = hiera('nemesis_mail_pw')
  $nemesis_mail_from = hiera('nemesis_mail_from')
  file { "${root_dir}/local.ini":
    owner   => 'root',
    group   => 'root',
    mode    => '0600',
    content => template('sr_site/userman.ini.erb'),
    require => Vcsrepo[$root_dir],
  }
}
