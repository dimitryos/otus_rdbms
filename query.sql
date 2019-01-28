/*
set @id_trip := 314;
set @id_station_a := 4862;
set @id_station_b := 3522;

-- explain format=json
select
    trs.vagon_ord_num, 
    seat_placement,
    min(round(price_basic*k*491)) as price_from, 
    any_value(perevozchik_name) as perevozchik_name, 
    any_value(service_class_code) as service_class_code, 
    sum(if(id_vagon_type=29, 1, 0)) as has_heavy_luggage_coupe,
    sum(is_invalid) as has_invalid_seats
from 
    trip_seats as trs
    inner join trip as tr using(id_trip)
    inner join marshrut_confs as mc on (tr.id_marshrut = mc.id_marshrut and trs.vagon_ord_num = mc.vagon_ord_num and trs.seat_num = mc.seat_num)
where 
    trs.id_trip=@id_trip and trs.id_station=@id_station_a and id_ticket_order is null and mc.id_vagon_category=6
group by     vagon_ord_num, seat_placement
;
*/
/*
ALTER TABLE `vagon_conf` 
ADD COLUMN `seat_placement` tinyint unsigned
GENERATED ALWAYS AS (
   case
        when ((`id_vagon_type` = 15) and (`seat_num` = 37)) then 5
        when ((`id_vagon_type` = 15) and (`seat_num` between 38 and 51) and ((`seat_num` % 2) = 0)) then 4
        when ((`id_vagon_type` = 15) and (`seat_num` between 39 and 51) and ((`seat_num` % 2) != 0)) then 3
        when ((`id_vagon_type` = 15) and (`seat_num` between 33 and 36) and ((`seat_num` % 2) = 0)) then 7
        when ((`id_vagon_type` = 15) and (`seat_num` between 33 and 36) and ((`seat_num` % 2) != 0)) then 6
        when ((`id_vagon_type` in (3,4,29,30,12,13,14,15)) and ((`seat_num` % 2) = 0)) then 2
        when ((`id_vagon_type` in (3,4,29,30,12,13,14,15)) and ((`seat_num` % 2) != 0)) then 1
   end 
) 
VIRTUAL
AFTER `coupe_num`
;

ALTER TABLE `vagon_conf` 
add COLUMN `k` decimal(4,3) unsigned
GENERATED ALWAYS AS (
   case 
    when (`is_invalid` = 1) then 0.5 
    when (`seat_placement` = 2) then 0.85 
    when (`seat_placement` = 3) then 0.85 
    when (`seat_placement` = 4) then 0.75 
    when (`seat_placement` = 5) then 0.9 
    when (`seat_placement` = 6) then 0.9 
    when (`seat_placement` = 7) then 0.9 
    else 1.0 end
) 
VIRTUAL
AFTER `is_invalid`
;
*/

create table seat_placement (
    `id_seat_placement` tinyint unsigned not null,
	`name_seat_placement` varchar(120),
	
	primary key (`id_seat_placement`)
) 
comment 'Справочник вариантов расположения места в вагоне'
engine=innodb
;

insert into seat_placement values 
(1, 'Нижнее'),
(2, 'Верхнее'),
(3, 'Нижнее боковое'),
(4, 'Верхнее боковое'),
(5, 'Нижнее боковое у туалета'),
(6, 'Последнее купе, нижнее'),
(7, 'Последнее купе, верхнее')
;