
/* для небольшой оптимизации отключаем на время подгрузки проверки ограничений */
SET unique_checks=0;
SET foreign_key_checks=0;

USE trains;

LOAD DATA INFILE '/var/lib/mysql-files/train.txt' 
INTO TABLE train 
COLUMNS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
; 


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


LOAD DATA INFILE '/var/lib/mysql-files/marshrut.txt' 
INTO TABLE marshrut 
COLUMNS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
;

LOAD DATA INFILE '/var/lib/mysql-files/marshrut_names.txt' 
INTO TABLE marshrut_names 
COLUMNS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
;

LOAD DATA INFILE '/var/lib/mysql-files/passenger.txt' 
INTO TABLE passenger 
COLUMNS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
;

LOAD DATA INFILE '/var/lib/mysql-files/passenger_pdata.txt' 
INTO TABLE passenger_pdata 
COLUMNS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
;

LOAD DATA INFILE '/var/lib/mysql-files/sostav_conf.txt' 
INTO TABLE sostav_conf 
COLUMNS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
;

LOAD DATA INFILE '/var/lib/mysql-files/sostav_type.txt' 
INTO TABLE sostav_type 
COLUMNS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
;

LOAD DATA INFILE '/var/lib/mysql-files/trip.txt' 
INTO TABLE trip 
COLUMNS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
;

LOAD DATA INFILE '/var/lib/mysql-files/trip_schedule.txt' 
INTO TABLE trip_schedule 
COLUMNS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
;

LOAD DATA INFILE '/var/lib/mysql-files/vagon_conf.txt' 
INTO TABLE vagon_conf 
COLUMNS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
(id_vagon_type, seat_num, coupe_num, is_invalid, gender_constraints, k)
;

COMMIT;
 
/* включаем проверки обратно */
SET unique_checks=1;
SET foreign_key_checks=1;
