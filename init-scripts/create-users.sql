drop user if exists 'admin'@'%';

create user 'admin'@'%' identified with mysql_native_password by 'admin';
grant all on *.* to 'admin'@'%';

flush privileges;