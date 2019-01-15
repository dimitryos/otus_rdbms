
/* для небольшой оптимизации отключаем на время подгрузки проверки ограничений */
SET unique_checks=0;
SET foreign_key_checks=0;

USE trains;

LOAD DATA INFILE '/var/lib/mysql-files/perevozchik.txt' 
INTO TABLE perevozchik 
COLUMNS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
; 


LOAD DATA INFILE '/var/lib/mysql-files/railway.txt' 
INTO TABLE railway 
COLUMNS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
; 


LOAD DATA INFILE '/var/lib/mysql-files/station.txt' 
INTO TABLE station 
COLUMNS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY '\\'
LINES TERMINATED BY '\n'
; 


LOAD DATA INFILE '/var/lib/mysql-files/vagon_category.txt' 
INTO TABLE vagon_category 
COLUMNS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
; 


LOAD DATA INFILE '/var/lib/mysql-files/vagon_type.txt' 
INTO TABLE vagon_type 
COLUMNS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
; 


LOAD DATA INFILE '/var/lib/mysql-files/service_option.txt' 
INTO TABLE service_option 
COLUMNS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
;


LOAD DATA INFILE '/var/lib/mysql-files/service_class.txt' 
INTO TABLE service_class 
COLUMNS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
;


LOAD DATA INFILE '/var/lib/mysql-files/service_class_options.txt' 
INTO TABLE service_class_options 
COLUMNS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
;

 
/* включаем проверки обратно */
SET unique_checks=1;
SET foreign_key_checks=1;
