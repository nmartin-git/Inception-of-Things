Vagrant.configure("2") do |config|

  # =========================
  # SERVER
  # =========================
  config.vm.define "maissatS" do |server|

    # Box Ubuntu
    server.vm.box = "ubuntu/bionic64"

    # Hostname
    server.vm.hostname = "maissatS"

    # IP privée
    server.vm.network "private_network", ip: "192.168.56.110"

    # Ressources VirtualBox
    server.vm.provider "virtualbox" do |v|
      v.memory = 512
      v.cpus = 1
    end

  end


  # =========================
  # SERVER WORKER
  # =========================
  config.vm.define "maissatSW" do |worker|

    # Box Ubuntu
    worker.vm.box = "ubuntu/bionic64"

    # Hostname
    worker.vm.hostname = "maissatSW"

    # IP privée
    worker.vm.network "private_network", ip: "192.168.56.111"

    # Ressources VirtualBox
    worker.vm.provider "virtualbox" do |v|
      v.memory = 512
      v.cpus = 1
    end

  end

end