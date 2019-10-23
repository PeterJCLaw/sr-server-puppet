
class sr_site::fw_pre {

  firewall { '000 accept all icmp':
    proto  => 'icmp',
    action => 'accept',
  }

  firewall { '001 allow loopback':
    iniface => 'lo',
    chain => 'INPUT',
    action => 'accept',
  }

  # Allow all traffic attached to established connections. Important for
  # connections made by the server.
  firewall { '000 INPUT allow related and established':
    state => ['RELATED', 'ESTABLISHED'],
    action => 'accept',
    proto => 'all',
  }

  # Allow everyone to connect to ssh.
  firewall { '002 ssh':
    proto  => 'tcp',
    dport => 22,
    action => 'accept',
  }

  # Allow everyone to connect to the anonymous git service.
  firewall { '003 git':
    proto => 'tcp',
    dport => 9418,
    action => 'accept',
  }

  # Allow everyone to connect to the HTTP website.
  firewall { '004 http':
    proto => 'tcp',
    dport => 80,
    action => 'accept',
  }

  # Allow everyone to connect to the SSL website
  firewall { '005 https':
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

# Chain INPUT (policy ACCEPT 0 packets, 0 bytes)
#  pkts bytes target     prot opt in     out     source               destination
# 64702  215M ACCEPT     all  --  any    any     anywhere             anywhere             state RELATED,ESTABLISHED /* 000 INPUT allow related and established (v4) */
#     0     0 ACCEPT     icmp --  any    any     anywhere             anywhere             /* 000 accept all icmp (v4) */
#    17  1020 ACCEPT     tcp  --  lo     any     anywhere             anywhere             /* 001 allow loopback (v4) */
#    10   440 ACCEPT     tcp  --  any    any     anywhere             anywhere             multiport dports ssh /* 002 ssh (v4) */
#     0     0 ACCEPT     tcp  --  any    any     anywhere             anywhere             multiport dports git /* 003 git (v4) */
#     2   120 ACCEPT     tcp  --  any    any     anywhere             anywhere             multiport dports http /* 004 http (v4) */
#     0     0 ACCEPT     tcp  --  any    any     anywhere             anywhere             multiport dports https /* 005 https (v4) */
#    11   640 ACCEPT     tcp  --  any    any     172.17.0.0/24        anywhere             multiport dports mysql /* 100 docker -> MySQL */
#     0     0 ACCEPT     tcp  --  any    any     172.17.0.0/24        anywhere             multiport dports ldap /* 101 docker -> LDAP */
#    92  3700 REJECT     tcp  --  any    any     anywhere             anywhere             /* 999 reject all (v4) */ reject-with icmp-port-unreachable

# Chain FORWARD (policy DROP 0 packets, 0 bytes)
#  pkts bytes target     prot opt in     out     source               destination
#     0     0 DOCKER-USER  all  --  any    any     anywhere             anywhere
#     0     0 DOCKER-ISOLATION-STAGE-1  all  --  any    any     anywhere             anywhere
#     0     0 ACCEPT     all  --  any    docker0  anywhere             anywhere             ctstate RELATED,ESTABLISHED
#     0     0 DOCKER     all  --  any    docker0  anywhere             anywhere
#     0     0 ACCEPT     all  --  docker0 !docker0  anywhere             anywhere
#     0     0 ACCEPT     all  --  docker0 docker0  anywhere             anywhere

# Chain OUTPUT (policy ACCEPT 8074 packets, 1156K bytes)
#  pkts bytes target     prot opt in     out     source               destination

# Chain DOCKER (1 references)
#  pkts bytes target     prot opt in     out     source               destination
#     0     0 ACCEPT     tcp  --  !docker0 docker0  anywhere             172.17.0.2           tcp dpt:http

# Chain DOCKER-ISOLATION-STAGE-1 (1 references)
#  pkts bytes target     prot opt in     out     source               destination
#     0     0 DOCKER-ISOLATION-STAGE-2  all  --  docker0 !docker0  anywhere             anywhere
#     0     0 RETURN     all  --  any    any     anywhere             anywhere

# Chain DOCKER-ISOLATION-STAGE-2 (1 references)
#  pkts bytes target     prot opt in     out     source               destination
#     0     0 DROP       all  --  any    docker0  anywhere             anywhere
#     0     0 RETURN     all  --  any    any     anywhere             anywhere

# Chain DOCKER-USER (1 references)
#  pkts bytes target     prot opt in     out     source               destination
#     0     0 RETURN     all  --  any    any     anywhere             anywhere
