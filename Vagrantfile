
$schema = <<-SCRIPT
    echo Создаём схему базы данных...
    cd /vagrant
    mysql -u root -proot < create-schema.sql
    echo Готово.
SCRIPT

$unpack_table_data = <<-SCRIPT
    echo Распаковываем данные справочных таблиц...
    cd /vagrant
    tar -xzvf csv.tgz -C /var/lib/mysql-files/
    echo Готово.
SCRIPT

$load_data_dicts = <<-SCRIPT
    echo Загружаем данные из справочников...
    cd /vagrant
    mysql -u root -proot < load-data-dicts.sql
    echo Готово.
SCRIPT

Vagrant.configure("2") do |config|
    config.vm.box = "dimitryos/mysql8"
	config.vm.box_version = "1.0"
  
    config.vm.provider "virtualbox" do |v|
      v.default_nic_type = "Am79C973"
    end  
    
	config.ssh.password = "vagrant"
	
    # MySQL8 Server port forwarding
	config.vm.network "forwarded_port", guest: 3306, host: 3307 
    
    config.vm.provision "shell", inline: $schema
    config.vm.provision "shell", inline: $unpack_table_data
    config.vm.provision "shell", inline: $load_data_dicts
end