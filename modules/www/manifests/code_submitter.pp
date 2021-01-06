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

  $env_file = "${root_dir}/.env"
  file { $env_file:
    ensure  => present,
    owner   => 'wwwcontent',
    group   => 'apache',
    mode    => '0640',
    content => template('www/code-submitter.env.erb'),
    require => Vcsrepo[$root_dir],
  }

  file { '/etc/sr/code-submitter-credentials.yaml':
    ensure => present,
    owner => 'wwwcontent',
    group => 'apache',
    mode => '440',
    source => "/srv/secrets/code-submitter-credentials.yaml",
    require => File['/etc/sr'],
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
    require         => Class['python'],
    virtualenv      => 'python3 -m virtualenv',
    subscribe       => Vcsrepo[$root_dir],
  }

  # Work around python::virtualenv's requirements handling blocking use of
  # binary packages:
  python::requirements { $venv_dir:
    owner           => 'wwwcontent',
    group           => 'apache',
    virtualenv      => $venv_dir,
    requirements    => $deploy_requirements,
    subscribe       => [
      Vcsrepo[$root_dir],
      Python::Virtualenv[$venv_dir],
    ],
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
      Python::Requirements[$venv_dir],
      File[$env_file],
    ],
  }

  $runtime_dir_name = 'code-submitter'
  sr_site::systemd_service { 'code-submitter':
    desc    => 'Code Submission Service',
    dir     => $root_dir,
    user    => 'wwwcontent',
    command => "${venv_dir}/bin/uvicorn code_submitter.server:app --uds /var/run/${runtime_dir_name}/code-submitter.socket --forwarded-allow-ips='*' --root-path /code-submitter",
    runtime_dir => $runtime_dir_name,
    subscribe => [
      Vcsrepo[$root_dir],
      Python::Virtualenv[$venv_dir],
      Python::Requirements[$venv_dir],
      File[$env_file],
    ],
  }
}
