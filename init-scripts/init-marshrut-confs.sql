
use trains;

drop table if exists marshrut_confs;

CREATE TABLE marshrut_confs (
    `id_marshrut` smallint unsigned, 
    `id_train` smallint unsigned,
    `train_num` varchar(20),
    `vagon_ord_num` tinyint unsigned, 
    `id_vagon_category` tinyint unsigned, 
    `name_vagon_category` varchar(120), 
    `id_vagon_type` tinyint unsigned, 
    `id_perevozchik` tinyint unsigned, 
    `perevozchik_name` varchar(120), 
    `coupe_num` tinyint unsigned, 
    `seat_num` tinyint unsigned, 
    `id_seat_placement` tinyint unsigned, 
    `name_seat_placement` varchar(120), 
    `is_invalid` tinyint unsigned, 
    `gender_constraints` tinyint unsigned, 
    `id_service_class` tinyint unsigned, 
    `service_class_code` varchar(80), 
    `price_basic` decimal(5,3) unsigned, 
    `k` decimal(4,3)
)
ENGINE=MEMORY
select distinct
    id_marshrut, 
    id_train,
    train_num,
    vagon_ord_num, 
    vcat.id_vagon_category, 
    vcat.name_vagon_category, 
    sc.id_vagon_type, 
    p.id_perevozchik,
    p.`name` as perevozchik_name,
    coupe_num, 
    seat_num, 
    vc.id_seat_placement, 
	name_seat_placement,
    is_invalid, 
    gender_constraints, 
    srvc.id_service_class, 
    srvc.service_class_code, 
    price_basic, 
    k
from 
    marshrut as m 
    inner join marshrut_names as mn using(id_marshrut)
    inner join train as t using(id_train)
    inner join sostav_conf as sc using(id_sostav_type)
    inner join vagon_conf as vc on (sc.id_vagon_type=vc.id_vagon_type)
    inner join vagon_type as vt on (vc.id_vagon_type=vt.id_vagon_type)
    inner join vagon_category as vcat using(id_vagon_category)
    inner join service_class AS srvc ON sc.id_service_class=srvc.id_service_class
    inner join perevozchik as p ON vt.id_perevozchik=p.id_perevozchik
	left join seat_placement as sp using(id_seat_placement)
;

CREATE INDEX idx_id_marshrut_mc ON marshrut_confs (id_marshrut, vagon_ord_num, seat_num) USING BTREE;
