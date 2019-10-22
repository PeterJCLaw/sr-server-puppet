# A wall of fire!

class sr_site::firewall {
  # Purge unmanaged firewall resources
  #
  # This will clear any existing rules, and make sure that only rules
  # defined in puppet exist on the machine
  resources { 'firewall':
    purge => true,
  }

  class { 'firewall':
    ensure => running,
  }

  class { 'sr_site::fw_pre':
    require => Service['iptables'],
  }

  class { 'sr_site::fw_post':
    require => Service['iptables'],
  }
}
