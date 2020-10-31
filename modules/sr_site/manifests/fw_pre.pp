
class sr_site::fw_pre {

  define common_rule(
    $action,
    $chain = undef,
    $dport = undef,
    $iniface = undef,
    $proto = undef,
    $state = undef
  ) {
    firewall { "${title} (v4)":
      provider  => 'iptables',
      action    => $action,
      chain     => $chain,
      dport     => $dport,
      iniface   => $iniface,
      proto     => $proto,
      state     => $state,
    }
    firewall { "${title} (v6)":
      provider => 'ip6tables',
      action    => $action,
      chain     => $chain,
      dport     => $dport,
      iniface   => $iniface,
      proto     => $proto,
      state     => $state,
    }
  }

  firewall { '000 accept all icmp (v4)':
    provider => 'iptables',
    proto  => 'icmp',
    action => 'accept',
  }

  firewall { '000 accept all icmpv6 (v6)':
    provider => 'ip6tables',
    proto  => 'ipv6-icmp',
    action => 'accept',
  }

  sr_site::fw_pre::common_rule { '001 allow loopback':
    iniface => 'lo',
    chain => 'INPUT',
    action => 'accept',
  }

  # Allow all traffic attached to established connections. Important for
  # connections made by the server.
  sr_site::fw_pre::common_rule { '000 INPUT allow related and established':
    state => ['RELATED', 'ESTABLISHED'],
    action => 'accept',
    proto => 'all',
  }

  # Allow everyone to connect to ssh.
  sr_site::fw_pre::common_rule { '002 ssh':
    proto  => 'tcp',
    dport => 22,
    action => 'accept',
  }

  if hiera('volunteer_services') {
    # Allow everyone to connect to the anonymous git service.
    sr_site::fw_pre::common_rule { '003 git':
      proto => 'tcp',
      dport => 9418,
      action => 'accept',
    }
  }

  # Allow everyone to connect to the HTTP website.
  sr_site::fw_pre::common_rule { '004 http':
    proto => 'tcp',
    dport => 80,
    action => 'accept',
  }

  # Allow everyone to connect to the SSL website
  sr_site::fw_pre::common_rule { '005 https':
    proto => 'tcp',
    dport => 443,
    action => 'accept',
  }

  if hiera('competitor_services') {
    # Allow docker (for the PHPBB forums) to connect to LDAP and MySQL
    firewall { '100 docker -> MySQL':
      source => '172.17.0.1/24',
      dport => 3306,
      action => 'accept',
    }
    firewall { '101 docker -> LDAP':
      source => '172.17.0.1/24',
      dport => 389,
      action => 'accept',
    }
  }
}
