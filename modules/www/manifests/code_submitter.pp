class www::code_submitter  (
  $git_root,
  $root_dir,
) {
  vcsrepo { $root_dir:
    ensure    => present,
    provider  => git,
    # TOOD: move to srobo org
    source    => 'https://github.com/PeterJCLaw/code-submitter',
    revision  => 'origin/master',
    owner     => 'wwwcontent',
    group     => 'apache',
  }

  $verify_tls = !$devmode
  $env_file = "${root_dir}/.env"
  file { $env_file:
    ensure  => present,
    owner   => 'wwwcontent',
    group   => 'apache',
    mode    => '0640',
    content => template('www/code-submitter.env.erb'),
    require => Vcsrepo[$root_dir],
  }

  package { 'make':
    ensure  => present,
  }

  $deploy_requirements = "${root_dir}/deploy-requirements.txt"
  file { $deploy_requirements:
    ensure  => present,
    owner   => 'wwwcontent',
    group   => 'apache',
    mode    => '0640',
    source  => "puppet:///modules/www/code-submitter-requirements.txt",
    require => [Vcsrepo[$root_dir], Package['make']],
  }

  $venv_dir = "${root_dir}/venv"
  python::virtualenv { $venv_dir:
    ensure          => present,
    owner           => 'wwwcontent',
    group           => 'apache',
    distribute      => false,
    version         => '3',
    requirements    => $deploy_requirements,
    require         => [Class['python'], Package['python3-virtualenv']],
    virtualenv      => 'python3 -m virtualenv',
    subscribe       => Vcsrepo[$root_dir],
  }

  # Create/upgrade the database schema
  exec { 'install-database':
    command     => "${venv_dir}/bin/alembic upgrade head",
    user        => 'wwwcontent',
    group       => 'apache',
    cwd         => $root_dir,
    environment => "PYTHONPATH=${root_dir}",
    subscribe   => [
      Vcsrepo[$root_dir],
      Python::Virtualenv[$venv_dir],
      File[$env_file],
    ],
  }

  # TODO: need to ensure this is present after a reboot!
  # TODO: ensure nginx can read this!
  $socket_dir = '/var/run/code-submitter'
  file { $socket_dir:
    ensure  => directory,
    owner   => 'wwwcontent',
    group   => 'apache',
    mode    => '0644',
  }

  sr_site::systemd_service { 'code-submitter':
    desc    => 'Code Submission Service',
    dir     => $root_dir,
    user    => 'wwwcontent',
    command => "${venv_dir}/bin/uvicorn code_submitter.server:app --uds ${socket_dir}/code-submitter.socket",
    require => File[$socket_dir],
    subscribe => [
      Vcsrepo[$root_dir],
      Python::Virtualenv[$venv_dir],
      File[$env_file],
    ],
  }
}
