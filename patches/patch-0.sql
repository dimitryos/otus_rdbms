/**
 * ИСПРАВЛЕНИЕ СТРУКТУРЫ ТАБЛИЦЫ trip_seats
 *
 * Убран индекс по полю id_ticket_order, поскольку он используется редко и только в процедуре возврата билета, а расходы на его перестроение 
 * при последующих операциях обновления будут неоправдано велики.
 * Оставлен один составной индекс по полям (`id_trip`, `id_station`, `vagon_ord_num`) поскольку это наиболее часто используемая комбинация полей при выборке из этой таблицы.
 * Добавлено отсутствовшое ранее указание количества партиций. Без него создаётся по умолчанию только одна партиция, что не имело смысла.
 */

USE trains;

DROP TABLE IF EXISTS `trip_seats`;

CREATE TABLE `trip_seats` (
  `id_trip` int UNSIGNED NOT NULL,
  `id_station` SMALLINT UNSIGNED NOT NULL,
  `vagon_ord_num` TINYINT UNSIGNED NOT NULL,
  `coupe_num` TINYINT UNSIGNED DEFAULT NULL,
  `seat_num` TINYINT UNSIGNED NOT NULL,
  `gender_constraints` TINYINT UNSIGNED DEFAULT NULL,
  `gender_constraints_vc` TINYINT UNSIGNED DEFAULT NULL,
  `id_ticket_order` int UNSIGNED DEFAULT NULL
) 
PARTITION BY HASH (`id_trip`) 
PARTITIONS 50
;

LOAD DATA INFILE '/var/lib/mysql-files/trip_seats.csv' 
INTO TABLE trip_seats 
COLUMNS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
(id_trip, id_station, vagon_ord_num, seat_num, coupe_num, gender_constraints_vc)
; 

CREATE INDEX `idx_trip_station_trs` ON `trip_seats` (`id_trip`, `id_station`, `vagon_ord_num`) USING BTREE;
