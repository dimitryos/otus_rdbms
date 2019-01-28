
$create_tablespace = <<-SCRIPT
    echo 'Создаём табличное пространство для хранения персональных данных...'
    if [[ ! -f /var/lib/mysql/confident.ibd ]]; then
        cd /vagrant/init-scripts
        mysql -u root -proot < create-tablespace.sql
    fi
    echo Готово.
SCRIPT

$create_schema = <<-SCRIPT
    echo 'Создаём схему базы данных trains...'
    cd /vagrant/init-scripts
    mysql -u root -proot < create-schema.sql
    echo Готово.
SCRIPT

$create_routines = <<-SCRIPT
    echo 'Создаём хранимые процедуры...'
    cd /vagrant/init-scripts
    mysql -u root -proot < create-routines.sql
    echo Готово.
SCRIPT

$create_user = <<-SCRIPT
    echo 'Создаём регулярного пользователя admin...'
    cd /vagrant/init-scripts
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
    tar -xjvf csv.tar.bz2 -C "$MYSQL_FILES_DIR"
    echo Готово.
SCRIPT

$load_table_data = <<-SCRIPT
    echo 'Загружаем рабочие данные...'
    cd /vagrant/init-scripts
    mysql -u root -proot < load-table-data.sql
    echo Готово.
SCRIPT

$load_trip_seats = <<-SCRIPT
    echo 'Загружаем данные по местам для поездок в таблицу trip_seats (процесс может занимать 15-20 минут)...'
    cd /vagrant/init-scripts
    mysql -u root -proot < load-trip-seats.sql
    echo Готово.
SCRIPT

$create_marshrut_confs = <<-SCRIPT
    echo 'Создаём и наполняем данными таблицу marshrut_confs'
    cd /vagrant/init-scripts
    mysql -u root -proot < init-marshrut-confs.sql
	
	TRAINS_DB_CNF=/etc/mysql/mysql.conf.d/trains_db.cnf
	if [[ -z $(grep init-file "$TRAINS_DB_CNF") ]]; then
	   echo 'Добавляем в конфигурацию сервера mysql путь к файлу автозапуска с кодом инициализации таблицы marshrut_confs при последующих перезапусках сервера'
       cp -f init-file.sql /home/vagrant/
       sudo sed -i -e '$a init-file = /home/vagrant/init-file.sql' "$TRAINS_DB_CNF"
	fi
    
	echo Готово.
SCRIPT

Vagrant.configure("2") do |config|
    config.vm.box = "dimitryos/mysql8"
	config.vm.box_version = "1.2"
  
    config.vm.provider "virtualbox" do |v|
      v.default_nic_type = "Am79C973"
    end  
    
    config.ssh.private_key_path = "private_key"
    
    # MySQL8 Server port forwarding
	config.vm.network "forwarded_port", guest: 3306, host: 3307 
    
    config.vm.provision "shell", inline: $create_tablespace
    config.vm.provision "shell", inline: $create_schema
    config.vm.provision "shell", inline: $create_routines
    config.vm.provision "shell", inline: $create_user
    config.vm.provision "shell", inline: $unpack_table_data
    config.vm.provision "shell", inline: $load_table_data
    config.vm.provision "shell", inline: $create_marshrut_confs
    config.vm.provision "shell", inline: $load_trip_seats
end