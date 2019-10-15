# SRobo Server puppet

This is the puppet config for our server.

High level documentation and how to get started with this all lies at:

https://www.studentrobotics.org/trac/wiki/ServerConfig

We also have separate instructions for how to commission a
[new production machine](./new-machine.md).

## Linting

`puppet-lint` can be used to lint the puppet. To use it do these things:

0. Have ruby
1. `bundle install`
2. `bundle exec rake lint`

## Vagrant Setup

1. Initialise the submodules (`git submodule update --init --recursive`)
2. Clone the dummy-secrets alongside this repo (`git clone git://srobo.org/server/dummy-secrets.git ../dummy-secrets`)
3. Install VirtualBox, usually in your distro's repos, or https://www.virtualbox.org/wiki/Downloads
4. Install Vagrant, usually in your distro's repos, or http://www.vagrantup.com/downloads.html
5. Run `vagrant up --provision`
6. Wait a while, depending on your internet connection
7. Run `vagrant ssh` to log into the box. You have passwordless sudo from the
   vagrant user to root. In case you need to know the password it's 'vagrant'.
8. Configure a hosts entry (add the following line to `/etc/hosts` on the
   *host* machine): `192.168.42.42 sr-vm sr-vm.local`
9. Point your browser at <https://sr-vm> to see the website the VM is hosting.

## Structure

The services configured are broken into roughly three parts, based on their
uses:

 - Competitor Services: things needed so that the competitors can compete -- the
   IDE & forums, plus various dependencies of theirs -- LDAP, nemesis, etc.
 - Volunteer Services: things exclusively for volunteers -- trac, git hosting
   etc.

Note: historically this config also include competition services ([SRComp][srcomp]
etc.), however as SRComp now has its own [deployment configuration][srcomp-puppet]
that is used instead.

Each of these can be enabled independently and the configuration is expected to
work under all combinations of them.

[srcomp]: https://github.com/PeterJCLaw/srcomp
[srcomp-puppet]: https://github.com/PeterJCLaw/srcomp-puppet

## Enabling specific things

Configuration of each service as well as of each of the service groups mentioned
above is handled through `hiera`. You can configure overrides for your local VM
by creating a file at `hieradata/nodes/sr-vm.local.yaml`. You probably want to
copy one of the existing "nodes" level files and modify it.
