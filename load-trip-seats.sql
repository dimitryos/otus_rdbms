USE trains;

LOAD DATA INFILE '/var/lib/mysql-files/trip_seats.csv' 
INTO TABLE trip_seats 
COLUMNS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
(id_trip, id_station, vagon_ord_num, seat_num, coupe_num, gender_constraints_vc)
; 

COMMIT;