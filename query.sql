
/*
drop temporary table if exists marshrut_confs;

create temporary table marshrut_confs as
select distinct
    id_marshrut, 
    vcat.id_vagon_category, 
    sc.id_vagon_type, 
    p.`name` as perevozchik_name, 
    vagon_ord_num, coupe_num, 
    seat_num, 
    is_upper, 
    is_invalid, 
    gender_constraints, 
    sc.id_service_class, 
    service_class_code,
    price_basic, 
    k
from 
    marshrut as m 
    inner join sostav_conf as sc using(id_sostav_type)
    inner join vagon_conf as vc on (sc.id_vagon_type=vc.id_vagon_type)
    inner join vagon_type as vt on (vc.id_vagon_type=vt.id_vagon_type)
    inner join vagon_category as vcat using(id_vagon_category)
    inner join perevozchik as p on vt.id_perevozchik=p.id_perevozchik
    inner join service_class as srvc on sc.id_service_class=srvc.id_service_class
order by
    id_marshrut, vagon_ord_num, seat_num
;
*/
select
    trs.vagon_ord_num, 
    if(is_upper>0, 'upper', 'lower') as placement,
    min(round(price_basic*k*251)) as price_from, 
    any_value(perevozchik_name) as perevozchik_name, 
    any_value(service_class_code) as service_class_code, 
    sum(if(id_vagon_type=29, 1, 0)) as has_heavy_luggage_coupe,
    sum(is_invalid) as has_invalid_seats
from 
    trip_seats as trs
    inner join trip as tr using(id_trip)
    inner join marshrut_confs as mc on (tr.id_marshrut = mc.id_marshrut and trs.vagon_ord_num = mc.vagon_ord_num and trs.seat_num = mc.seat_num)
where 
    trs.id_trip=@id_trip and trs.id_station=@id_station_a and id_ticket_order is null and mc.id_vagon_category=5
group by vagon_ord_num, is_upper
;
