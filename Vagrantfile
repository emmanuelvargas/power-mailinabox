
# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "debian/buster64"
  config.vm.provider :virtualbox do |vb|
    vb.customize ["modifyvm", :id, "--cpus", 4, "--memory", 4096]
  end
  config.vm.provider :libvirt do |v|
    v.memory = 4096
    v.cpus = 4
    v.nested = true
  end
  config.vm.provider :kvm do |kvm|
    kvm.memory_size = '4096m'
  end

  # Network config: Since it's a mail server, the machine must be connected
  # to the public web. However, we currently don't want to expose SSH since
  # the machine's box will let anyone log into it. So instead we'll put the
  # machine on a private network.
  config.vm.hostname = "mailinabox.lan"
  config.vm.network "private_network", ip: "192.168.50.4"
  config.vm.synced_folder ".", "/vagrant", nfs_version: "3"
  #, :mount_options => ["ro"]

  config.vm.provision "shell", :inline => <<-SH
    # Set environment variables so that the setup script does
    # not ask any questions during provisioning. We'll let the
    # machine figure out its own public IP.
    export NONINTERACTIVE=1
    export PUBLIC_IP=192.168.50.4
    export PUBLIC_IPV6=auto
    export PRIMARY_HOSTNAME=auto
    export SKIP_NETWORK_CHECKS=1
    # Start the setup script.
    cd /vagrant
    setup/start.sh
    # After setup is done, fully open the ssh ports again
    ufw allow ssh
SH
  config.vm.provision "shell", run: "always", :inline => <<-SH
    service mailinabox restart
SH
end
