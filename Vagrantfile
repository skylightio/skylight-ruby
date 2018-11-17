# -*- mode: ruby -*-
# vi: set ft=ruby :

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

unless Vagrant.has_plugin?("vagrant-vbguest")
  raise "The vbguest plugin is required. Install with `vagrant plugin install vagrant-vbguest`."
end

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.box = "ubuntu/trusty64"

  config.vm.network "private_network", type: "dhcp"
  config.vm.synced_folder ".", "/vagrant", type: "nfs"

  config.vm.provision "shell", path: "provision.sh", privileged: false
end
