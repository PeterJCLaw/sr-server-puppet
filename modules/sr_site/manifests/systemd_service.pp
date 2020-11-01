define sr_site::systemd_service(
  $command,
  $user,
  $desc,
  $dir = undef,
  $runtime_dir = undef,
  $depends = ['network.target'],
  $subs = [],
) {
  $service_name = "${title}.service"
  $service_file = "/etc/systemd/system/${service_name}"

  $service_description = $desc
  $start_dir = $dir
  $start_command = $command
  $depends_str = join($depends, ' ')

  file { $service_file:
    ensure  => present,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => template('sr_site/service.erb'),
  } ->
  file { "/etc/systemd/system/multi-user.target.wants/${service_name}":
    ensure  => link,
    target  => $service_file,
  } ->
  exec { "${title}-systemd-load":
    provider  => 'shell',
    command   => 'systemctl daemon-reload',
    onlyif    => "systemctl --all | grep -F ${service_name}; if test $? = 0; then exit 1; fi; exit 0",
    subscribe => File[$service_file],
  } ->
  service { $title:
    ensure    => running,
    enable    => true,
    subscribe => union([File[$service_file]], $subs),
  }
}
