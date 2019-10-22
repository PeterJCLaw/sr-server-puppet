
class sr_site::fw_post {

  firewall { '999 drop all (v4)':
    provider  => 'iptables',
    action    => 'drop',
  }

  firewall { '999 drop all (v6)':
    provider  => 'ip6tables',
    action    => 'drop',
  }

}
