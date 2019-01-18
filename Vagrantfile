
$create_schema = <<-SCRIPT
    echo 'Создаём схему базы данных...'
    cd /vagrant
    mysql -u root -proot < create-schema.sql
    echo Готово.
SCRIPT

$create_user = <<-SCRIPT
    echo 'Создаём регулярного пользователя admin...'
    cd /vagrant
    mysql -u root -proot < create-users.sql
    echo Готово.
SCRIPT

$unpack_table_data = <<-SCRIPT
    echo 'Распаковываем данные справочных таблиц...'
    MYSQL_FILES_DIR=/var/lib/mysql-files
    if [[ -d "$MYSQL_FILES_DIR" && ! -z "$(ls -A "$MYSQL_FILES_DIR" 2>/dev/null)" ]]; then
        rm "$MYSQL_FILES_DIR"/*
    fi
    cd /vagrant
    tar -xzvf csv.tgz -C "$MYSQL_FILES_DIR"
    echo Готово.
SCRIPT

$load_data_dicts = <<-SCRIPT
    echo 'Загружаем данные из справочников...'
    cd /vagrant
    mysql -u root -proot < load-data-dicts.sql
    echo Готово.
SCRIPT

$load_trip_seats = <<-SCRIPT
    echo 'Загружаем данные по местам для поездок (процесс может занимать 15-20 минут)...'
    cd /vagrant
    mysql -u root -proot < load-trip-seats.sql
    echo Готово.
SCRIPT

Vagrant.configure("2") do |config|
    config.vm.box = "dimitryos/mysql8"
	config.vm.box_version = "1.1"
  
    config.vm.provider "virtualbox" do |v|
      v.default_nic_type = "Am79C973"
    end  
    
    config.ssh.private_key_path = "private_key"
    
    # MySQL8 Server port forwarding
	config.vm.network "forwarded_port", guest: 3306, host: 3307 
    
    config.vm.provision "shell", inline: $create_schema
    config.vm.provision "shell", inline: $create_user
    config.vm.provision "shell", inline: $unpack_table_data
    config.vm.provision "shell", inline: $load_data_dicts
    config.vm.provision "shell", inline: $load_trip_seats
end