Vagrant.configure("2") do |config|

    # Note: the base box likely doesn't contain a version of the guest additions
    # which matches that of your host VirtualBox. This will result in errors
    # that the `vboxfs` could not be found:
    #
    #   mount: unknown filesystem type 'vboxsf'
    #
    # To fix this you should install the `vagrant-vbguest` plugin:
    #
    #   vagrant plugin install vagrant-vbguest
    #
    # which will ensure that the versions match when you provision the VM.
    config.vm.box = "fedora/30-cloud-base"

    config.vm.provider "virtualbox" do |v|
        # The box defaults to 512, things are smoother if we have more
        v.memory = 1024
        # The box defaults to one, things are smoother if we have more
        v.cpus = 2
    end

    config.vm.network "private_network", ip: "192.168.42.42"
    config.vm.hostname = "sr-vm.local"

    # Secrets
    config.vm.synced_folder "../dummy-secrets", "/srv/secrets"

    # Hiera data, guest path must match the value in the hiera.yaml
    config.vm.synced_folder "hieradata", "/etc/puppet/hieradata"

    # Bootstrap
    config.vm.provision "shell", inline: "grep 'obsoletes=0' /etc/dnf/dnf.conf || echo 'obsoletes=0' >> /etc/dnf/dnf.conf"
    config.vm.provision "shell", inline: "yum install -y puppet git"

    config.vm.provision "puppet" do |puppet|
        puppet.hiera_config_path    = "hiera.yaml"
        puppet.environment_path     = "."
        puppet.manifests_path       = "manifests"
        puppet.manifest_file        = "main.pp"
        puppet.module_path          = "modules"
        # puppet.options              = "--verbose --debug"
    end
end
