/*
CREATE TABLE `trip_seats` (
  `id_trip` int unsigned NOT NULL,
  `id_station` smallint unsigned NOT NULL,
  `vagon_ord_num` tinyint unsigned NOT NULL,
  `seat_num` tinyint unsigned NOT NULL,
  `coupe_num` tinyint unsigned DEFAULT NULL,
  `is_reserved` tinyint unsigned NOT NULL DEFAULT '0',
  `gender_constraints` tinyint unsigned DEFAULT NULL,
  `gender_constraints_vc` tinyint unsigned DEFAULT NULL,
  
  INDEX `idx_trip_station` (`id_trip`,`id_station`)
) 
ENGINE=InnoDB 
COMMENT='Расклад по местам для заданной поездки (партиционирование по хэшу id поездки)'
PARTITION BY HASH(id_trip)
;
*/

desc trip_seats;