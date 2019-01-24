
# !!! В новом боксе добавить в /etc/mysql/my.cnf include /vagrant/*.cnf !!!

$create_tablespace = <<-SCRIPT
    echo 'Создаём табличное пространство для хранения персональных данных...'
    if [[ ! -f /var/lib/mysql/confident.ibd ]]; then
        cd /vagrant
        mysql -u root -proot < create-tablespace.sql
    fi
    echo Готово.
SCRIPT

$create_schema = <<-SCRIPT
    echo 'Создаём схему базы данных trains...'
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
    echo 'Распаковываем рабочие данные таблиц...'
    MYSQL_FILES_DIR=/var/lib/mysql-files
    if [[ -d "$MYSQL_FILES_DIR" && ! -z "$(ls -A "$MYSQL_FILES_DIR" 2>/dev/null)" ]]; then
        rm "$MYSQL_FILES_DIR"/*
    fi
    cd /vagrant
    tar -xzvf csv.tgz -C "$MYSQL_FILES_DIR"
    echo Готово.
SCRIPT

$load_table_data = <<-SCRIPT
    echo 'Загружаем рабочие данные...'
    cd /vagrant
    mysql -u root -proot < load-table-data.sql
    echo Готово.
SCRIPT

$load_trip_seats = <<-SCRIPT
    echo 'Загружаем данные по местам для поездок в таблицу trip_seats (процесс может занимать 15-20 минут)...'
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
    
    config.vm.provision "shell", inline: $create_tablespace
    config.vm.provision "shell", inline: $create_schema
    config.vm.provision "shell", inline: $create_user
    config.vm.provision "shell", inline: $unpack_table_data
    config.vm.provision "shell", inline: $load_table_data
    config.vm.provision "shell", inline: $load_trip_seats
end