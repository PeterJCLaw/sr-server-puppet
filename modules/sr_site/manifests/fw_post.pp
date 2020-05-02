
class sr_site::fw_post {

  firewall { '999 reject all (v4)':
    provider  => 'iptables',
    action    => 'reject',
  }

  firewall { '999 reject all (v6)':
    provider  => 'ip6tables',
    action    => 'reject',
  }

}
