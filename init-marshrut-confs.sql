
set max_heap_table_size = 17999872;

use trains;

drop table if exists marshrut_confs;

CREATE TABLE marshrut_confs (
    id_marshrut SMALLINT UNSIGNED, 
    vagon_ord_num TINYINT UNSIGNED, 
    id_vagon_category TINYINT UNSIGNED, 
    name_vagon_category varchar(120), 
    id_vagon_type TINYINT UNSIGNED, 
    id_perevozchik TINYINT UNSIGNED, 
    perevozchik_name varchar(120), 
    coupe_num TINYINT UNSIGNED, 
    seat_num TINYINT UNSIGNED, 
    seat_placement varchar(100), 
    is_invalid TINYINT UNSIGNED, 
    gender_constraints TINYINT UNSIGNED, 
    id_service_class TINYINT UNSIGNED, 
    service_class_code varchar(80), 
    price_basic DECIMAL(5,3) UNSIGNED, 
    k DECIMAL(4,3)
)
ENGINE=MEMORY
select distinct
    id_marshrut, 
    vagon_ord_num, 
    vcat.id_vagon_category, 
    vcat.name_vagon_category, 
    sc.id_vagon_type, 
    p.id_perevozchik,
    p.`name` as perevozchik_name,
    coupe_num, 
    seat_num, 
    seat_placement, 
    is_invalid, 
    gender_constraints, 
    srvc.id_service_class, 
    srvc.service_class_code, 
    price_basic, 
    k
from 
    marshrut as m 
    inner join sostav_conf as sc using(id_sostav_type)
    inner join vagon_conf as vc on (sc.id_vagon_type=vc.id_vagon_type)
    inner join vagon_type as vt on (vc.id_vagon_type=vt.id_vagon_type)
    inner join vagon_category as vcat using(id_vagon_category)
    inner join service_class AS srvc ON sc.id_service_class=srvc.id_service_class
    inner join perevozchik as p ON vt.id_perevozchik=p.id_perevozchik
;

CREATE INDEX idx_id_marshrut_mc ON marshrut_confs (id_marshrut, vagon_ord_num, seat_num) USING BTREE;
