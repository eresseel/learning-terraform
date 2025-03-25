# -*- mode: ruby -*
# vi: set ft=ruby

require 'fileutils'
require 'open-uri'

def ansible_playbook(instance, group=nil, name='setup', tags=nil, playbook='./vagrant_provision.yml')
    group ||= 'all'

    instance.vm.provision name, type: "ansible" do |ansible|
        ansible.playbook          = playbook
        ansible.config_file       = "ansible.cfg"
        ansible.galaxy_role_file  = "./roles/requirements.yml"
        ansible.galaxy_roles_path = "./roles"
        ansible.galaxy_command    = "ansible-galaxy install --role-file=%{role_file} --roles-path=%{roles_path}"
        if File.file?("#{ENV['HOME']}/.vagrant.d/vault_password_files.d/provision.txt") then
            ansible.vault_password_file = "#{ENV['HOME']}/.vagrant.d/vault_password_files.d/provision.txt"
        else
            ansible.ask_vault_pass = true
        end
        ansible.groups = {
            "server" => ["test-server"],
            "client" => ["test-client"]
        }
        ansible.limit = group
        unless tags.nil? || tags == ''
            ansible.tags  = tags
        end
    end
end

Vagrant.configure("2") do |config|
    config.vm.box_check_update = true
    vbox_default_vm_folder_path = `vboxmanage list systemproperties | grep machine | cut -d':' -f2 | awk '{print $1}'`.strip
    vbox_default_vm_disk_folder_path = File.join(vbox_default_vm_folder_path, "VirtualBoxDisk")

    # https://github.com/containerd/containerd/blob/main/docs/getting-started.md
    # https://dev.to/admantium/kubernetes-with-kubeadm-cluster-installation-from-scratch-51ae
    common_provision = <<-SCRIPT
        useradd -s /usr/bin/bash -m -g sudo ubuntu
        echo "ubuntu:root123" | chpasswd

        lvextend -l +100%FREE /dev/ubuntu-vg/ubuntu-lv
        resize2fs /dev/ubuntu-vg/ubuntu-lv
        sed -i '/swap/s/^/#/' /etc/fstab
        swapoff -a

        rm -rf /etc/modules-load.d/k8s.conf
        cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

        modprobe overlay
        modprobe br_netfilter

        rm -rf /etc/sysctl.d/k8s.conf
        cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
        sysctl --system

        apt-get update
        apt-get install -y apt-transport-https ca-certificates curl gpg apparmor apparmor-utils
        mkdir -p /etc/apt/keyrings
        rm -f /etc/apt/keyrings/docker.gpg
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

        apt-get update
        apt-get install -o Dpkg::Options::="--force-confold" -y --allow-change-held-packages containerd.io
        apt-mark hold containerd.io
        cp /home/vagrant/vagrant/configs/config-runc.toml /etc/containerd/config.toml
        systemctl restart containerd

        curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
        echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
        apt-get update

        apt-mark unhold kubeadm kubelet kubectl
        apt-get install -y kubelet kubeadm kubectl
        apt-mark hold kubeadm kubelet kubectl
        systemctl enable --now kubelet
    SCRIPT

    provision_master_init = <<-SCRIPT
        #{common_provision}

        export IP=$(ip a show dev eth1 | awk '/inet / {print $2}' | cut -f1 -d'/')
        kubeadm config images pull
        kubeadm init --control-plane-endpoint "${IP}:6443" --apiserver-advertise-address=${IP} --pod-network-cidr=192.168.0.0/16 --upload-certs | tee join-command.txt
        grep -A 3 "kubeadm join" join-command.txt | head -n 3 > master-token.sh
        grep -A 3 "kubeadm join" join-command.txt | tail -n 2 > worker-token.sh

        mkdir -p "${HOME}/.kube"
        cp -i /etc/kubernetes/admin.conf "${HOME}/.kube/config"
        chown "$(id -u):$(id -g)" "${HOME}/.kube/config"

        kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.1/manifests/tigera-operator.yaml
        kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.1/manifests/custom-resources.yaml

        bash /home/vagrant/vagrant/configs/checking.sh

        ctr --version
        kubeadm version
        kubelet --version
        kubectl get nodes
    SCRIPT

    provision_master_join = <<-SCRIPT
        #{common_provision}

        scp -i /home/vagrant/.ssh/id_rsa -o StrictHostKeyChecking=no vagrant@192.168.56.10:/home/vagrant/master-token.sh .
        sed -i "2i --apiserver-advertise-address $(ip a show dev eth1 | awk '/inet / {print $2}' | cut -f1 -d'/') #"  master-token.sh
        sed -i 's/#/\\\\/' master-token.sh
        bash master-token.sh

        mkdir -p $HOME/.kube
        cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
        chown $(id -u):$(id -g) $HOME/.kube/config
        kubectl get nodes
    SCRIPT

    provision_worker = <<-SCRIPT
        #{common_provision}

        scp -i /home/vagrant/.ssh/id_rsa -o StrictHostKeyChecking=no vagrant@192.168.56.10:/home/vagrant/worker-token.sh .
        sed -i "2i --apiserver-advertise-address $(ip a show dev eth1 | awk '/inet / {print $2}' | cut -f1 -d'/') #"  worker-token.sh
        sed -i 's/#/\\\\/' worker-token.sh
        bash worker-token.sh
    SCRIPT

    machines=[ {
        :box => [
            { :box_name => "generic/ubuntu2204" }
        ],
        :vm_name => "kubernetes-master-1",
        :hostname => "kubernetes-master-1",
        :network => [
            { :network_type => "private_network", :ip => "192.168.56.10" }
        ],
        :resource_limit => [ {:cpu => 2, :memory => 4096} ],
        :sync => [ { :src => "#{ENV['PWD']}", :dst => "/home/vagrant/vagrant" } ],
        :ssh => [
            { :vm_username => "vagrant", :ssh_key_path => "vagrant-files", :ssh_key_name => "id_rsa", :key_type => "rsa", :bit => 4096 }
        ],
        :file => [
            { :src => "vagrant-files/id_rsa", :dst => "/home/vagrant/.ssh/id_rsa" }
        ],
        :shell => provision_master_init,
    }, {
        :box => [
            { :box_name => "generic/ubuntu2204" }
        ],
        :vm_name => "kubernetes-master-2",
        :hostname => "kubernetes-master-2",
        :network => [
            { :network_type => "private_network", :ip => "192.168.56.11" }
        ],
        :resource_limit => [ {:cpu => 2, :memory => 4096} ],
        :sync => [ { :src => "#{ENV['PWD']}", :dst => "/home/vagrant/vagrant" } ],
        :ssh => [
            { :vm_username => "vagrant", :ssh_key_path => "vagrant-files", :ssh_key_name => "id_rsa", :key_type => "rsa", :bit => 4096 }
        ],
        :file => [
            { :src => "vagrant-files/id_rsa", :dst => "/home/vagrant/.ssh/id_rsa" }
        ],
        :shell => provision_master_join,
    }, {
        :box => [
            { :box_name => "generic/ubuntu2204" }
        ],
        :vm_name => "kubernetes-master-3",
        :hostname => "kubernetes-master-3",
        :network => [
            { :network_type => "private_network", :ip => "192.168.56.12" }
        ],
        :resource_limit => [ {:cpu => 2, :memory => 4096} ],
        :sync => [ { :src => "#{ENV['PWD']}", :dst => "/home/vagrant/vagrant" } ],
        :ssh => [
            { :vm_username => "vagrant", :ssh_key_path => "vagrant-files", :ssh_key_name => "id_rsa", :key_type => "rsa", :bit => 4096 }
        ],
        :file => [
            { :src => "vagrant-files/id_rsa", :dst => "/home/vagrant/.ssh/id_rsa" }
        ],
        :shell => provision_master_join,
    }, {
        :box => [
            { :box_name => "generic/ubuntu2204" }
        ],
        :vm_name => "kubernetes-worker-1",
        :hostname => "kubernetes-worker-1",
        :network => [
            { :network_type => "private_network", :ip => "192.168.56.20" }
        ],
        :resource_limit => [ {:cpu => 2, :memory => 4096} ],
        :sync => [ { :src => "#{ENV['PWD']}", :dst => "/home/vagrant/vagrant" } ],
        :ssh => [
            { :vm_username => "vagrant", :ssh_key_path => "vagrant-files", :ssh_key_name => "id_rsa", :key_type => "rsa", :bit => 4096 }
        ],
        :file => [
            { :src => "vagrant-files/id_rsa", :dst => "/home/vagrant/.ssh/id_rsa" }
        ],
        :shell => provision_worker,
    }, {
        :box => [
            { :box_name => "generic/ubuntu2204" }
        ],
        :vm_name => "kubernetes-worker-2",
        :hostname => "kubernetes-worker-2",
        :network => [
            { :network_type => "private_network", :ip => "192.168.56.21" }
        ],
        :resource_limit => [ {:cpu => 2, :memory => 4096} ],
        :sync => [ { :src => "#{ENV['PWD']}", :dst => "/home/vagrant/vagrant" } ],
        :ssh => [
            { :vm_username => "vagrant", :ssh_key_path => "vagrant-files", :ssh_key_name => "id_rsa", :key_type => "rsa", :bit => 4096 }
        ],
        :file => [
            { :src => "vagrant-files/id_rsa", :dst => "/home/vagrant/.ssh/id_rsa" }
        ],
        :shell => provision_worker,
    } ]

    machines.each do |machine|
        config.trigger.before :up do |trigger|
            trigger.name = "Running #{machine[:vm_name]} VM trigger"
            trigger.ruby do
                if (machine[:box][0].key?(:box_url) && machine[:box][0].key?(:box_local_file_name))
                    puts  "==> #{machine[:vm_name]}: Search custom box ..."
                    result = system("vagrant box list | grep '#{machine[:box][0][:box_name]}'")

                    if (!result)
                        begin
                            puts "==> #{machine[:vm_name]}: Custom box download ..."
                            File.write("#{machine[:box][0][:box_local_file_name]}", URI.open(machine[:box][0][:box_url]).read)
                            system("vagrant box add #{machine[:box][0][:box_name]} #{machine[:box][0][:box_local_file_name]}")
                            FileUtils.rm_rf("#{machine[:box][0][:box_local_file_name]}")
                        rescue StandardError => e
                            puts "Error: #{e.message}"
                        end
                    end
                end

                if (machine[:disk].is_a?(Array))
                    disk_path = File.join("#{vbox_default_vm_disk_folder_path.chomp}", "#{machine[:vm_name].gsub("-","_")}", "disks")
                    FileUtils.mkdir_p(disk_path) unless File.directory?(disk_path)
                end
            end
        end

        config.trigger.after :destroy do |trigger|
            trigger.name = "Running #{machine[:vm_name]} VM trigger"
            trigger.ruby do
                vbox_vm_disk_folder = File.join("#{vbox_default_vm_disk_folder_path.chomp}", "#{machine[:vm_name].gsub("-","_")}", "disks")
                if File.directory?(vbox_vm_disk_folder) && Dir.empty?(vbox_vm_disk_folder)
                    if (machine[:disk].is_a?(Array))
                        disk_path = File.join("#{vbox_default_vm_disk_folder_path.chomp}", "#{machine[:vm_name].gsub("-","_")}")
                        FileUtils.rm_rf(disk_path)
                    end
                end
                FileUtils.rm_rf("ansible.log")
            end
        end

        config.vm.define machine[:vm_name] do |node|
            provision_message = "Machine already provisioned. Run `vagrant provision #{machine[:vm_name]}`"
            ip_and_port_message = ""

            node.vm.box = machine[:box][0][:box_name]
            node.vm.hostname = machine[:hostname]

            if (machine[:network].is_a?(Array))
                machine[:network].each do |net|
                    if(net[:network_type] == "private_network")
                        node.vm.network net[:network_type], ip: net[:ip], auto_config: true, virtualbox_intnet: true
                    end
                    if(net[:network_type] == "public_network")
                        node.vm.network net[:network_type], bridge: net[:bridge_type]
                    end
                end
            end

            if (machine[:ssh].is_a?(Array))
                machine[:ssh].each do |sh|
                    FileUtils.mkdir_p(sh[:ssh_key_path]) unless File.directory?(sh[:ssh_key_path])
                    system("ssh-keygen -q -t #{sh[:key_type]} -b #{sh[:bit]} -N \'\' -f #{sh[:ssh_key_path]}/#{sh[:ssh_key_name]}") unless File.exist?("#{sh[:ssh_key_path]}/#{sh[:ssh_key_name]}")
                    node.vm.provision "shell" do |s|
                        if(File.directory?(sh[:ssh_key_path]))
                            ssh_pub_key = File.readlines("#{sh[:ssh_key_path]}/#{sh[:ssh_key_name]}.pub").first.strip
                            s.inline = "echo #{ssh_pub_key} >> /home/#{sh[:vm_username]}/.ssh/authorized_keys"
                        end
                    end
                end
            end

            if (machine[:file].is_a?(Array))
                machine[:file].each do |f|
                    node.vm.provision "file", source: "#{f[:src]}", destination: "#{f[:dst]}"
                end
            end

            if (machine[:sync].is_a?(Array))
                machine[:sync].each do |s|
                    node.vm.synced_folder "#{s[:src]}", "#{s[:dst]}", SharedFoldersEnableSymlinksCreate: false
                end
            end

            if (machine[:port].is_a?(Array))
                machine[:port].each do |p|
                    node.vm.network :forwarded_port, guest: "#{p[:guest]}", host: "#{p[:host]}"
                    ips = machine[:network].map { |item| item[:ip] }
                    ports = machine[:port].map { |item| item[:guest] }
                    ip_and_port_message = "The machine domain address: http://#{machine[:hostname]}/\n"

                    ips.each do |ip|
                        if ip
                            ip_and_port_message = ip_and_port_message \
                                    + "\nsudo echo '#{ip}  #{machine[:hostname]}' | sudo tee -a /etc/hosts"
                            ports.each do |port|
                                if port
                                    ip_and_port_message = ip_and_port_message \
                                            + "\nThe machine IP address: http://#{ip}:#{port}/"
                                end
                            end
                        end
                    end
                    node.vm.post_up_message = ip_and_port_message
                end
            end

            if (machine[:ansible].is_a?(Array))
                machine[:ansible].each do |a|
                    ansible_playbook(instance=node, group="#{a[:group]}")
                end
            end

            node.vm.provision "shell", inline: "#{machine[:shell]}" unless not machine [:shell].is_a?(String)
            node.vm.provision "shell", path: "#{machine[:script]}" unless not machine [:script].is_a?(String)

            if (machine.key?(:shell) || machine.key?(:script) || machine[:ansible].is_a?(Array) && !machine[:port].is_a?(Array))
                node.vm.post_up_message = provision_message
            end
            if (machine.key?(:shell) || machine.key?(:script) || machine[:ansible].is_a?(Array) && machine[:port].is_a?(Array))
                node.vm.post_up_message = provision_message \
                                        + "\n\n" \
                                        + ip_and_port_message
            end

            node.vm.provider "virtualbox" do |vbox|
                vbox.name = machine[:vm_name]
                vbox.linked_clone = true
                vbox.default_nic_type = "virtio"
                if (machine[:resource_limit].is_a?(Array) and machine[:resource_limit].length() == 1)
                        machine[:resource_limit].each do |resource|
                            vbox.memory = resource[:memory]
                            vbox.cpus = resource[:cpu]
                        end
                end

                if (machine[:disk].is_a?(Array) and !File.directory?(File.join("#{vbox_default_vm_disk_folder_path.chomp}", "#{machine[:vm_name].gsub("-","_")}", "disks")))
                    vbox.customize ['storagectl', :id, '--name', 'Virtual I/O Device SCSI controller', '--add', 'virtio-scsi', '--portcount', machine[:disk].length()]
                    machine[:disk].each_with_index do |d, index|
                        disk_file_name = "disk-#{index}.vdi"
                        disk_file_path = File.join("#{vbox_default_vm_disk_folder_path.chomp}", "#{machine[:vm_name].gsub("-","_")}", "disks", "#{disk_file_name}")
                        vbox.customize ['createhd', '--filename', disk_file_path, '--variant', d[:disk_type], '--size', d[:disk_size]*1024] unless File.exist?(disk_file_path)
                        vbox.customize ['storageattach', :id, '--storagectl', 'Virtual I/O Device SCSI controller', '--port', index, '--device', 0, '--type', 'hdd', '--medium', disk_file_path]
                    end
                end
            end
        end
    end
end