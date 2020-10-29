# Main NosBox Class
class NosBox
  def self.configure(config, settings)
    # Set The VM Provider
    ENV['VAGRANT_DEFAULT_PROVIDER'] = settings['provider'] ||= 'virtualbox'

    # Configure Local Variable To Access Scripts From Remote Location
    script_dir = File.dirname(__FILE__)

    # Allow SSH Agent Forward from The Box
    config.ssh.forward_agent = true

    # Configure Verify Host Key
    if settings.has_key?('verify_host_key')
      config.ssh.verify_host_key = settings['verify_host_key']
    end

    # Configure The Box
    config.vm.define settings['name'] ||= 'nosbox'
    config.vm.box = settings['box'] ||= 'nosbox/box'
    unless settings.has_key?('SpeakFriendAndEnter')
      config.vm.box_version = settings['version'] ||= '~> 3'
    end
    config.vm.hostname = settings['hostname'] ||= 'nosbox'

    # Configure A Private Network IP
    if settings['ip'] != 'autonetwork'
      config.vm.network :private_network, ip: settings['ip'] ||= '192.168.33.10'
    else
      config.vm.network :private_network, ip: '0.0.0.0', auto_network: true
    end

    # Configure Additional Networks
    if settings.has_key?('networks')
      settings['networks'].each do |network|
        config.vm.network network['type'], ip: network['ip'], mac: network['mac'], bridge: network['bridge'] ||= nil, netmask: network['netmask'] ||= '255.255.255.0'
      end
    end

    # Configure A Few VirtualBox Settings
    config.vm.provider 'virtualbox' do |vb|
      vb.name = settings['name'] ||= 'nosbox'
      vb.customize ['modifyvm', :id, '--memory', settings['memory'] ||= '2048']
      vb.customize ['modifyvm', :id, '--cpus', settings['cpus'] ||= '1']
      vb.customize ['modifyvm', :id, '--natdnsproxy1', 'on']
      vb.customize ['modifyvm', :id, '--natdnshostresolver1', settings['natdnshostresolver'] ||= 'on']
      vb.customize ['modifyvm', :id, '--ostype', 'Ubuntu_64']
      if settings.has_key?('gui') && settings['gui']
        vb.gui = true
      end
    end

    # Override Default SSH port on the host
    if settings.has_key?('default_ssh_port')
      config.vm.network :forwarded_port, guest: 22, host: settings['default_ssh_port'], auto_correct: false, id: "ssh"
    end

    # Configure A Few VMware Settings
    ['vmware_fusion', 'vmware_workstation'].each do |vmware|
      config.vm.provider vmware do |v|
        v.vmx['displayName'] = settings['name'] ||= 'nosbox'
        v.vmx['memsize'] = settings['memory'] ||= 2048
        v.vmx['numvcpus'] = settings['cpus'] ||= 1
        v.vmx['guestOS'] = 'ubuntu-64'
        if settings.has_key?('gui') && settings['gui']
          v.gui = true
        end
      end
    end

    # Configure A Few Hyper-V Settings
    config.vm.provider "hyperv" do |h, override|
      h.vmname = settings['name'] ||= 'nosbox'
      h.cpus = settings['cpus'] ||= 1
      h.memory = settings['memory'] ||= 2048
      h.linked_clone = true
      if settings.has_key?('hyperv_mac') && settings['hyperv_mac']
        h.mac = settings['hyperv_mac']
      end
      if settings.has_key?('hyperv_maxmemory') && settings['hyperv_maxmemory']
        h.maxmemory = settings['hyperv_maxmemory']
      end
      if settings.has_key?('hyperv_enable_virtualization_extensions') && settings['hyperv_enable_virtualization_extensions']
        h.enable_virtualization_extensions = true
      end

      if Vagrant.has_plugin?('vagrant-hostmanager')
        override.hostmanager.ignore_private_ip = true
      end
    end

    # Configure A Few Parallels Settings
    config.vm.provider 'parallels' do |v|
      v.name = settings['name'] ||= 'nosbox'
      v.update_guest_tools = settings['update_parallels_tools'] ||= false
      v.memory = settings['memory'] ||= 2048
      v.cpus = settings['cpus'] ||= 1
    end

    # Standardize Ports Naming Schema
    if settings.has_key?('ports')
      settings['ports'].each do |port|
        port['guest'] ||= port['to']
        port['host'] ||= port['send']
        port['protocol'] ||= 'tcp'
      end
    else
      settings['ports'] = []
    end

    # Default Port Forwarding
    default_ports = {
      80 => 8000,
      443 => 44300,
      3306 => 33060,
      4040 => 4040,
      5432 => 54320,
      8025 => 8025,
      9600 => 9600,
      27017 => 27017
    }

    # Use Default Port Forwarding Unless Overridden
    unless settings.has_key?('default_ports') && settings['default_ports'] == false
      default_ports.each do |guest, host|
        unless settings['ports'].any? { |mapping| mapping['guest'] == guest }
          config.vm.network 'forwarded_port', guest: guest, host: host, auto_correct: true
        end
      end
    end

    # Add Custom Ports From Configuration
    if settings.has_key?('ports')
      settings['ports'].each do |port|
        config.vm.network 'forwarded_port', guest: port['guest'], host: port['host'], protocol: port['protocol'], auto_correct: true
      end
    end

    # Configure The Public Key For SSH Access
    if settings.include? 'authorize'
      if File.exist? File.expand_path(settings['authorize'])
        config.vm.provision 'shell' do |s|
          s.inline = "echo $1 | grep -xq \"$1\" /home/vagrant/.ssh/authorized_keys || echo \"\n$1\" | tee -a /home/vagrant/.ssh/authorized_keys"
          s.args = [File.read(File.expand_path(settings['authorize']))]
        end
      end
    end

    # Copy The SSH Private Keys To The Box
    if settings.include? 'keys'
      if settings['keys'].to_s.length.zero?
        puts 'Check your NosBox.yaml file, you have no private key(s) specified.'
        exit
      end
      settings['keys'].each do |key|
        if File.exist? File.expand_path(key)
          config.vm.provision 'shell' do |s|
            s.privileged = false
            s.inline = "echo \"$1\" > /home/vagrant/.ssh/$2 && chmod 600 /home/vagrant/.ssh/$2"
            s.args = [File.read(File.expand_path(key)), key.split('/').last]
          end
        else
          puts 'Check your NosBox.yaml (or NosBox.json) file, the path to your private key does not exist.'
          exit
        end
      end
    end

    # Copy User Files Over to VM
    if settings.include? 'copy'
      settings['copy'].each do |file|
        config.vm.provision 'file' do |f|
          f.source = File.expand_path(file['from'])
          f.destination = file['to'].chomp('/') + '/' + file['from'].split('/').last
        end
      end
    end

    # Register All Of The Configured Shared Folders
    if settings.include? 'folders'
      settings['folders'].each do |folder|
        if File.exist? File.expand_path(folder['map'])
          mount_opts = []

          if ENV['VAGRANT_DEFAULT_PROVIDER'] == 'hyperv'
            folder['type'] = 'smb'
          end

          if folder['type'] == 'nfs'
            mount_opts = folder['mount_options'] ? folder['mount_options'] : ['actimeo=1', 'nolock']
          elsif folder['type'] == 'smb'
            mount_opts = folder['mount_options'] ? folder['mount_options'] : ['vers=3.02', 'mfsymlinks']

            smb_creds = {smb_host: folder['smb_host'], smb_username: folder['smb_username'], smb_password: folder['smb_password']}
          end

          # For b/w compatibility keep separate 'mount_opts', but merge with options
          options = (folder['options'] || {}).merge({ mount_options: mount_opts }).merge(smb_creds || {})

          # Double-splat (**) operator only works with symbol keys, so convert
          options.keys.each{|k| options[k.to_sym] = options.delete(k) }

          config.vm.synced_folder folder['map'], folder['to'], type: folder['type'] ||= nil, **options

          # Bindfs support to fix shared folder (NFS) permission issue on Mac
          if folder['type'] == 'nfs' && Vagrant.has_plugin?('vagrant-bindfs')
            config.bindfs.bind_folder folder['to'], folder['to']
          end
        else
          config.vm.provision 'shell' do |s|
            s.inline = ">&2 echo \"Unable to mount one of your folders. Please check your folders in NosBox.yaml\""
          end
        end
      end
    end




    # Update and Install LAMP
    config.vm.provision 'shell' do |s|
      s.path = script_dir + '/script.sh'
    end

    # Clear any existing apache sites
    config.vm.provision 'shell' do |s|
      s.path = script_dir + '/clear-apache.sh'
    end

    # Clear any Homestead sites and insert markers in /etc/hosts
    config.vm.provision 'shell' do |s|
      s.path = script_dir + '/hosts-reset.sh'
    end

    # Install All The Configured Nginx Sites
    if settings.include? 'sites'

      domains = []

      settings['sites'].each do |site|

        domains.push(site['map'])

        # Create SSL certificate
        config.vm.provision 'shell' do |s|
          s.name = 'Creating Certificate: ' + site['map']
          s.path = script_dir + '/create-certificate.sh'
          s.args = [site['map']]
        end

        if site['wildcard'] == 'yes'
          config.vm.provision 'shell' do |s|
            s.name = 'Creating Wildcard Certificate: *.' + site['map']
            s.path = script_dir + '/create-certificate.sh'
            s.args = ['*.' + site['map']]
          end
        end

        type = site['type'] ||= 'cakephp3'
        load_balancer = settings['load_balancer'] ||= false
        http_port = load_balancer ? '8111' : '80'
        https_port = load_balancer ? '8112' : '443'

        if load_balancer
          config.vm.provision 'shell' do |s|
            #s.path = script_dir + '/install-load-balancer.sh'
            s.path = script_dir + 'site-type/load-apache.sh'
          end
        end

        case type
        when 'apigility'
          type = 'zf'
        when 'expressive'
          type = 'zf'
        when 'symfony'
          type = 'symfony2'
        end

        config.vm.provision 'shell' do |s|
          s.name = 'Creating Site: ' + site['map']
          if site.include? 'params'
            params = '('
            site['params'].each do |param|
              params += ' [' + param['key'] + ']=' + param['value']
            end
            params += ' )'
          end
          if site.include? 'headers'
            headers = '('
            site['headers'].each do |header|
              headers += ' [' + header['key'] + ']=' + header['value']
            end
            headers += ' )'
          end
          if site.include? 'rewrites'
            rewrites = '('
            site['rewrites'].each do |rewrite|
              rewrites += ' [' + rewrite['map'] + ']=' + "'" + rewrite['to'] + "'"
            end
            rewrites += ' )'
            # Escape variables for bash
            rewrites.gsub! '$', '\$'
          end

          # Convert the site & any options to an array of arguments passed to the
          # specific site type script (defaults to laravel)
          s.path = script_dir + "/site-types/#{type}.sh"
          s.args = [
              site['map'],                # $1
              site['to'],                 # $2
              site['port'] ||= http_port, # $3
              site['ssl'] ||= https_port, # $4
              site['php'] ||= '7.4',      # $5
              params ||= '',              # $6
              site['xhgui'] ||= '',       # $7
              site['exec'] ||= 'false',   # $8
              headers ||= '',             # $9
              rewrites ||= ''             # $10
          ]

          # Should we use the wildcard ssl?
          if site['wildcard'] == 'yes' or site['use_wildcard'] == 'yes'
            if site['use_wildcard'] != 'no'
              config.vm.provision 'shell' do |s|
                s.inline = "sed -i \"s/$1.crt/*.$1.crt/\" /etc/apache2/sites-available/$1-ssl.conf"
                s.args = [site['map']]
              end

              config.vm.provision 'shell' do |s|
                s.inline = "sed -i \"s/$1.key/*.$1.key/\" /etc/apache2/sites-available/$1-ssl.conf"
                s.args = [site['map']]
              end
              
            end
          end

          # generate pm2 json config file
          if site['pm2']
            config.vm.provision "shell" do |s2|
              s2.name = 'Creating Site Ecosystem for pm2: ' + site['map']
              s2.path = script_dir + "/create-ecosystem.sh"
              s2.args = Array.new
              s2.args << site['pm2'][0]['name']
              s2.args << site['pm2'][0]['script'] ||= "npm"
              s2.args << site['pm2'][0]['args'] ||= "run serve"
              s2.args << site['pm2'][0]['cwd']
            end
          end

        end

        config.vm.provision 'shell' do |s|
          s.path = script_dir + "/hosts-add.sh"
          s.args = ['127.0.0.1', site['map']]
        end

      end
    end

    # Configure All Of The Server Environment Variables
    config.vm.provision 'shell' do |s|
      s.name = 'Clear Variables'
      s.path = script_dir + '/clear-variables.sh'
    end

    if settings.has_key?('variables')
      settings['variables'].each do |var|
        config.vm.provision 'shell' do |s|
          s.inline = "echo \"\nenv[$1] = '$2'\" >> /etc/php/5.6/fpm/pool.d/www.conf"
          s.args = [var['key'], var['value']]
        end

        config.vm.provision 'shell' do |s|
          s.inline = "echo \"\nenv[$1] = '$2'\" >> /etc/php/7.0/fpm/pool.d/www.conf"
          s.args = [var['key'], var['value']]
        end

        config.vm.provision 'shell' do |s|
          s.inline = "echo \"\nenv[$1] = '$2'\" >> /etc/php/7.1/fpm/pool.d/www.conf"
          s.args = [var['key'], var['value']]
        end

        config.vm.provision 'shell' do |s|
          s.inline = "echo \"\nenv[$1] = '$2'\" >> /etc/php/7.2/fpm/pool.d/www.conf"
          s.args = [var['key'], var['value']]
        end

        config.vm.provision 'shell' do |s|
          s.inline = "echo \"\nenv[$1] = '$2'\" >> /etc/php/7.3/fpm/pool.d/www.conf"
          s.args = [var['key'], var['value']]
        end

        config.vm.provision 'shell' do |s|
          s.inline = "echo \"\nenv[$1] = '$2'\" >> /etc/php/7.4/fpm/pool.d/www.conf"
          s.args = [var['key'], var['value']]
        end

        config.vm.provision 'shell' do |s|
          s.inline = "echo \"\n# Set Homestead Environment Variable\nexport $1=$2\" >> /home/vagrant/.profile"
          s.args = [var['key'], var['value']]
        end
      end

      config.vm.provision 'shell' do |s|
        s.inline = 'service php5.6-fpm restart;service php7.0-fpm restart;service  php7.1-fpm restart; service php7.2-fpm restart; service php7.3-fpm restart; service php7.4-fpm restart; service php8.0-fpm restart;'
      end
    end

    config.vm.provision 'shell' do |s|
      s.name = 'Restarting Cron'
      s.inline = 'sudo service cron restart'
    end

    config.vm.provision 'shell' do |s|
      s.name = 'Restart Webserver'
      s.path = script_dir + '/restart-webserver.sh'
    end

    # Configure All Of The Configured Databases
    if settings.has_key?('databases')
      # Check which databases are enabled
      enabled_databases = Array.new
      if settings.has_key?('features')
        settings['features'].each do |feature|
          feature_name = feature.keys[0]
          feature_arguments = feature[feature_name]

          # If feature is set to false, ignore
          if feature_arguments == false
            next
          end

          enabled_databases.push feature_name
        end
      end

      settings['databases'].each do |db|
        config.vm.provision 'shell' do |s|
          s.name = 'Creating MySQL Database: ' + db
          s.path = script_dir + '/create-mysql.sh'
          s.args = [db]
        end

        config.vm.provision 'shell' do |s|
          s.name = 'Creating Postgres Database: ' + db
          s.path = script_dir + '/create-postgres.sh'
          s.args = [db]
        end

      end
    end


    # Update Composer On Every Provision
    config.vm.provision 'shell' do |s|
      s.name = 'Update Composer'
      s.inline = 'sudo chown -R vagrant:vagrant /usr/local/bin && sudo -u vagrant /usr/local/bin/composer self-update --no-progress && sudo chown -R vagrant:vagrant /home/vagrant/.composer/'
      s.privileged = false
    end

    if settings.has_key?('backup') && settings['backup'] && (Vagrant::VERSION >= '2.1.0' || Vagrant.has_plugin?('vagrant-triggers'))
      dir_prefix = '/vagrant/'
      settings['databases'].each do |database|
        NosBox.backup_mysql(database, "#{dir_prefix}/mysql_backup", config)
        NosBox.backup_postgres(database, "#{dir_prefix}/postgres_backup", config)
      end
    end

  end

  def self.backup_mysql(database, dir, config)
    now = Time.now.strftime("%Y%m%d%H%M")
    config.trigger.before :destroy do |trigger|
      trigger.warn = "Backing up mysql database #{database}..."
      trigger.run_remote = {inline: "mkdir -p #{dir}/#{now} && mysqldump --routines #{database} > #{dir}/#{now}/#{database}-#{now}.sql"}
    end
  end

  def self.backup_postgres(database, dir, config)
    now = Time.now.strftime("%Y%m%d%H%M")
    config.trigger.before :destroy do |trigger|
      trigger.warn = "Backing up postgres database #{database}..."
      trigger.run_remote = {inline: "mkdir -p #{dir}/#{now} && echo localhost:5432:#{database}:root:root > ~/.pgpass && chmod 600 ~/.pgpass && pg_dump -U root -h localhost #{database} > #{dir}/#{now}/#{database}-#{now}.sql"}
    end
  end
end