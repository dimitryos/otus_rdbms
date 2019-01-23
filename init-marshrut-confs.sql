
set max_heap_table_size = 32000000;

drop table if exists marshrut_confs;

CREATE TABLE marshrut_confs (
    id_marshrut SMALLINT UNSIGNED, 
    id_vagon_category TINYINT UNSIGNED, 
    id_vagon_type TINYINT UNSIGNED, 
    perevozchik_name varchar(120), 
    vagon_ord_num TINYINT UNSIGNED, 
    coupe_num TINYINT UNSIGNED, 
    seat_num TINYINT UNSIGNED, 
    is_upper TINYINT UNSIGNED, 
    is_invalid TINYINT UNSIGNED, 
    gender_constraints TINYINT UNSIGNED, 
    id_service_class TINYINT UNSIGNED, 
    price_basic DECIMAL(5,3) UNSIGNED, 
    k DECIMAL(4,3)
)
ENGINE=MEMORY
select distinct
    id_marshrut, 
    vcat.id_vagon_category, 
    sc.id_vagon_type, 
    p.`name` as perevozchik_name,
    vagon_ord_num, 
    coupe_num, 
    seat_num, 
    is_upper, 
    is_invalid, 
    gender_constraints, 
    id_service_class, 
    price_basic, 
    k
from 
    marshrut as m 
    inner join sostav_conf as sc using(id_sostav_type)
    inner join vagon_conf as vc on (sc.id_vagon_type=vc.id_vagon_type)
    inner join vagon_type as vt on (vc.id_vagon_type=vt.id_vagon_type)
    inner join vagon_category as vcat using(id_vagon_category)
    inner join perevozchik as p using(id_perevozchik)
;

CREATE INDEX idx_id_marshrut_mc ON marshrut_confs (id_marshrut, vagon_ord_num, seat_num) USING BTREE;
