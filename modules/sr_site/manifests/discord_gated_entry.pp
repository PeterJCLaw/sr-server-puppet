class sr_site::discord_gated_entry (
  $git_root,
  $root_dir,
) {
  user { 'discord':
    ensure  => present,
    comment => 'Discord bot service user',
    shell   => '/sbin/nologin',
    gid     => 'users',
  }

  vcsrepo { $root_dir:
    ensure    => present,
    provider  => git,
    source    => 'https://github.com/srobo/discord-gated-entry',
    revision  => 'origin/main',
    owner     => 'discord',
    group     => 'users',
    require   => User['discord'],
  }

  $env_file = "${root_dir}/.env"
  $discord_gated_entry_token = hiera('discord_gated_entry_token')
  file { $env_file:
    ensure  => present,
    owner   => 'discord',
    group   => 'users',
    mode    => '0640',
    content => template('sr_site/discord-gated-entry.env.erb'),
    require => Vcsrepo[$root_dir],
  }

  $venv_dir = "${root_dir}/venv"
  python::virtualenv { $venv_dir:
    ensure          => present,
    owner           => 'discord',
    group           => 'users',
    distribute      => false,
    version         => '3',
    require         => Class['python'],
    virtualenv      => 'python3 -m virtualenv',
    subscribe       => Vcsrepo[$root_dir],
  }

  python::requirements { $venv_dir:
    owner           => 'discord',
    group           => 'users',
    virtualenv      => $venv_dir,
    requirements    => "${root_dir}/requirements.txt",
    subscribe       => [
      Vcsrepo[$root_dir],
      Python::Virtualenv[$venv_dir],
    ],
  }

  $runtime_dir_name = 'discord-gated-entry'
  sr_site::systemd_service { 'discord-gated-entry':
    desc        => 'Discord bot for gated entry',
    dir         => $root_dir,
    user        => 'discord',
    command     => "${venv_dir}/bin/python main.py",
    runtime_dir => $runtime_dir_name,
    subscribe   => [
      Vcsrepo[$root_dir],
      Python::Virtualenv[$venv_dir],
      Python::Requirements[$venv_dir],
      File[$env_file],
    ],
  }
}
