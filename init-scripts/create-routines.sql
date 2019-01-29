use trains;

delimiter ;;

drop function if exists route_length;

create function route_length(
    _id_marshrut smallint unsigned, 
    _id_station_a smallint unsigned, 
    _id_station_b smallint unsigned
)
returns smallint
reads sql data
COMMENT 'Вычисляет расстояние между станциями _id_station_a и _id_station_b, находящимися на маршруте _id_marshrut'
begin
    declare km_a smallint unsigned;
    declare km_b smallint unsigned;
    
    select km_from_start from marshrut where id_marshrut = _id_marshrut and id_station = _id_station_a into km_a;
    select km_from_start from marshrut where id_marshrut = _id_marshrut and id_station = _id_station_b into km_b;
    
    return (km_b - km_a);
end
;;


DROP PROCEDURE if EXISTS get_marshrut_info;

CREATE PROCEDURE get_marshrut_info(
	IN _id_trip INT UNSIGNED
)
READS SQL DATA
COMMENT 'Вывод списка возможных вариантов поездов, следующих по заданному маршруту от станции А до станции Б на определенную дату с сопутсвующей информацией'
BEGIN
    SELECT 
        station_name, 
        DATE_FORMAT(arrive_time, '%H:%i') AS arrive_time, 
        DATE_FORMAT(stop_time, '%H:%i') AS stop_time, 
        DATE_FORMAT(departure_time, '%H:%i') AS departure_time,
        CONCAT(hour(reach_time) div 24, ' д ', hour(reach_time) mod 24, ' ч ', minute(reach_time), ' мин') AS reach_time
    FROM 
        trip as tr 
        INNER JOIN marshrut USING(id_marshrut)
        INNER JOIN station USING(id_station)
    WHERE 
        id_trip = _id_trip
    ORDER BY 
        order_number
    ;
END 
;;


DROP PROCEDURE if EXISTS get_train_variants_info;

CREATE PROCEDURE get_train_variants_info(
	IN _id_station_a SMALLINT UNSIGNED,
	IN _id_station_b SMALLINT UNSIGNED,
	IN _date_trip DATE 
)
READS SQL DATA
COMMENT 'Вывод списка возможных вариантов поездов, следующих по заданному маршруту от станции А до станции Б на определенную дату с сопутсвующей информацией'
BEGIN
	WITH mrsh_cte AS (
		/* 
		 * Получаем список маршрутов, которые содержат как А, так и Б в заданном порядке.
		 * Для последующих соединений в том числе паралелльно также выводим: 
		 *		id и названия станций,
		 *		время в пути между станциями,
		 *		id конфигурации состава, который будет отправляться от начальной станции А.
		 * По каждому маршруту всю выводимую информацию распологаем в одну строку.
		 */
		SELECT 
			ma.id_marshrut, 
			_id_station_a AS id_station_a,
			(SELECT station_name FROM station WHERE id_station=_id_station_a) AS station_name_start, 
			TIMEDIFF(mb.reach_time, IFNULL(ma.reach_time, maketime(0,0,0))) AS travel_time,
			_id_station_b AS id_station_b,
			(SELECT station_name FROM station WHERE id_station=_id_station_b) AS station_name_end,
			ma.id_sostav_type
		FROM 
			marshrut AS ma CROSS JOIN marshrut AS mb 
		WHERE
		    ma.id_marshrut=mb.id_marshrut
		    AND ma.id_station=_id_station_a
		    AND mb.id_station=_id_station_b
		    AND ma.order_number < mb.order_number
	),
	trains_cte AS (
		/*
		 * К полученной ранее информации о маршрутах присоединяем соответствующую информацию:
		 *   о поезде,
		 *   о дате и времени отправления и прибытия.
		 */
		SELECT 
			tr.id_trip, 
			t.id_train, t.train_num, t.train_name,
			mrsh_cte.station_name_start,
			mrsh_cte.station_name_end,
			(
				SELECT trs.departure_dt 
				FROM trip_schedule AS trs 
				WHERE trs.id_trip=tr.id_trip AND trs.id_station=_id_station_a
			) AS start_dt,
			mrsh_cte.travel_time,
			(
				SELECT trs.arrive_dt 
				FROM trip_schedule AS trs 
				WHERE trs.id_trip=tr.id_trip AND trs.id_station=_id_station_b
			) AS end_dt,
			mrsh_cte.id_sostav_type
		FROM 
			mrsh_cte 
			INNER JOIN marshrut_names AS mn ON mrsh_cte.id_marshrut=mn.id_marshrut
			INNER JOIN train AS t ON mn.id_train=t.id_train
			INNER JOIN trip AS tr ON mrsh_cte.id_marshrut=tr.id_marshrut
		WHERE 
			tr.`DATE`=_date_trip
	)
	/*
	 * По каждой поездке присоединяем информацию о задействованных перевозчиках.
	 * Применяем группировку с конкатенацией, чтобы вся информация о поезде была в одной строке.
	 */
	SELECT 
		id_trip, 
		any_value(id_train) AS id_train, 
		any_value(train_num) AS train_num,
		any_value(train_name) AS train_name,
		any_value(station_name_start) AS train_name,
		any_value(station_name_end) AS station_name_end,
		any_value(start_dt) AS start_dt,
		any_value(travel_time) AS travel_time,
		any_value(end_dt) AS end_dt,
		GROUP_CONCAT(distinct p.NAME) AS perevozchik_name
	FROM 
		trains_cte 
		INNER JOIN sostav_conf AS st ON trains_cte.id_sostav_type=st.id_sostav_type
        INNER JOIN vagon_type AS vt ON st.id_vagon_type=vt.id_vagon_type
		INNER JOIN perevozchik AS p ON vt.id_perevozchik=p.id_perevozchik
	GROUP BY 
		id_trip
	;
END 
;;


DROP PROCEDURE if EXISTS basic_vagon_prices;

CREATE PROCEDURE basic_vagon_prices(
	IN _id_trip INT UNSIGNED,
	IN _id_station_a SMALLINT UNSIGNED,
	IN _id_station_b SMALLINT UNSIGNED
)
READS SQL DATA
COMMENT 'Получение списка нижнего порога цен на проезд от А до станции Б для заданной поездки в зависимости от категории вагона с выводом сопутствующей информации (версия для движка MEMORY)'
BEGIN
    declare _id_marshrut smallint unsigned;
    
    select id_marshrut from trip where id_trip = _id_trip into _id_marshrut;
    
    select
        name_vagon_category, 
        sum(is_invalid) as has_invalid_seats,
        sum(if(id_vagon_type=29, 1, 0)) as has_heavy_luggage_coupe,
        count(*) as vacant_seats_total, 
        min(round(price_basic*k*route_length(_id_marshrut, _id_station_a, _id_station_b))) as price_vagon_itog
    from 
        trip_seats as trs
        inner join trip as tr using(id_trip)
        inner join marshrut_confs as mc on (tr.id_marshrut = mc.id_marshrut and trs.vagon_ord_num = mc.vagon_ord_num and trs.seat_num = mc.seat_num)
    where 
        trs.id_trip=_id_trip and trs.id_station=_id_station_a and id_ticket_order is null
    group by
        id_vagon_category
    ;
END 
;;


DROP PROCEDURE if EXISTS basic_vagon_prices_v;

CREATE PROCEDURE basic_vagon_prices_v(
	IN _id_trip INT UNSIGNED,
	IN _id_station_a SMALLINT UNSIGNED,
	IN _id_station_b SMALLINT UNSIGNED
)
READS SQL DATA
COMMENT 'версия на вьюшке'
BEGIN
    declare _id_marshrut smallint unsigned;
    
    select id_marshrut from trip where id_trip = _id_trip into _id_marshrut;
    
    select
        any_value(name_vagon_category) as name_vagon_category, 
        sum(is_invalid) as has_invalid_seats,
        sum(if(mc.id_vagon_type=29, 1, 0)) as has_heavy_luggage_coupe,
        count(*) as vacant_seats_total, 
        min(round(price_basic*k*route_length(_id_marshrut, _id_station_a, _id_station_b))) as price_vagon_itog
    from 
        trip_seats as trs
        inner join trip as tr using(id_trip)
        inner join v_marshrut_confs as mc on (tr.id_marshrut = mc.id_marshrut and trs.vagon_ord_num = mc.vagon_ord_num and trs.seat_num = mc.seat_num)
    where 
        trs.id_trip=_id_trip and trs.id_station=_id_station_a and trs.id_ticket_order is null 
    group by
        mc.id_vagon_category
    ;
END 
;;


DROP PROCEDURE if EXISTS basic_vagon_prices_j;

CREATE PROCEDURE basic_vagon_prices_j(
	IN _id_trip INT UNSIGNED,
	IN _id_station_a SMALLINT UNSIGNED,
	IN _id_station_b SMALLINT UNSIGNED
)
READS SQL DATA
COMMENT 'версия на вьюшке'
BEGIN
    declare _id_marshrut smallint unsigned;
    
    select id_marshrut from trip where id_trip = _id_trip into _id_marshrut;
    
    select
        any_value(name_vagon_category) as name_vagon_category, 
        sum(is_invalid) as has_invalid_seats,
        sum(if(vc.id_vagon_type=29, 1, 0)) as has_heavy_luggage_coupe,
        count(*) as vacant_seats_total, 
        min(round(price_basic*k*route_length(_id_marshrut, _id_station_a, _id_station_b))) as price_vagon_itog
    from 
        trip_seats as trs
        inner join trip as tr using(id_trip)
        inner join marshrut as m on (tr.id_marshrut = m.id_marshrut)
        inner join sostav_conf as sc on (m.id_sostav_type = sc.id_sostav_type and trs.vagon_ord_num = sc.vagon_ord_num)
        inner join vagon_conf as vc on (sc.id_vagon_type=vc.id_vagon_type and trs.seat_num = vc.seat_num)
        inner join vagon_type as vt on (vc.id_vagon_type=vt.id_vagon_type)
        inner join vagon_category as vcat using(id_vagon_category)
        inner join service_class AS srvc on sc.id_service_class=srvc.id_service_class
        inner join perevozchik as p on vt.id_perevozchik=p.id_perevozchik
    where 
        trs.id_trip=_id_trip and trs.id_station=_id_station_a and trs.id_ticket_order is null 
    group by
        vt.id_vagon_category
    ;
END 
;;


DROP PROCEDURE if EXISTS `basic_vagon_info`;

CREATE PROCEDURE `basic_vagon_info` (
    IN _id_trip INT UNSIGNED,
    IN _id_station_a SMALLINT UNSIGNED,
    IN _id_station_b SMALLINT UNSIGNED,
    IN _id_vagon_category TINYINT UNSIGNED
) 
READS SQL DATA 
COMMENT 'Для заданного отправления выводит общую информацию о ценах и сервисных услугах по каждому номеру вагона в составе, в котором есть наличие свободных мест, с группировкой по типу расположения места'
BEGIN 
    declare _id_marshrut smallint unsigned;
    
    select id_marshrut from trip where id_trip = _id_trip into _id_marshrut;
    
    select
        /* № вагона */
        trs.vagon_ord_num, 
        /* тип расположения места */
        ANY_VALUE(name_seat_placement) as placement,
        /* количество свободных мест с данным типом расположения*/
        COUNT(*) AS vacant_seats_qty,
        /* нижний порог цены для данной группы мест */
        MIN(round(price_basic * k * route_length(_id_marshrut, _id_station_a, _id_station_b))) as price_from, 
        /* название перевозчика, которому принадлежит данный вагон в составе */
        ANY_VALUE(perevozchik_name) as perevozchik_name, 
        /* класс обслуживания вагона */
        ANY_VALUE(service_class_code) as service_class_code, 
        /* наличие специального багажного купе */
        SUM(if(id_vagon_type=29, 1, 0)) as has_heavy_luggage_coupe,
        /* наличие места для инвалида в данном вагоне */
        SUM(is_invalid) as has_invalid_seats,
        /* сервисные услуги, доступные для данного вагона */
        GROUP_CONCAT(distinct so.id_service_option) AS id_service_options
    from 
        trip_seats as trs
        inner join trip as tr using(id_trip)
        inner join marshrut_confs as mc on (tr.id_marshrut = mc.id_marshrut and trs.vagon_ord_num = mc.vagon_ord_num and trs.seat_num = mc.seat_num)
        inner join service_class_options AS sco ON mc.id_service_class=sco.id_service_class
        inner join service_option AS so ON sco.id_service_option=so.id_service_option
    where 
        trs.id_trip=_id_trip and trs.id_station=_id_station_a and id_ticket_order is null and mc.id_vagon_category=_id_vagon_category
    group by 
        vagon_ord_num, id_seat_placement
    ;
END
;;


DROP PROCEDURE if EXISTS vagon_vacant_seats;

CREATE PROCEDURE vagon_vacant_seats (
    IN _id_trip INT UNSIGNED,
    IN _id_station_a SMALLINT UNSIGNED,
    IN _vagon_ord_num TINYINT UNSIGNED,
    IN _route_length SMALLINT UNSIGNED
)
READS SQL DATA
COMMENT 'Выводит список мест в данном вагоне с выводом информации о цене, месторасположении в вагоне и ограничениях по полу для заданной станции отправления'
BEGIN
    WITH vagon_seats AS (
        select 
            trs.coupe_num,
            trs.seat_num,
            name_seat_placement,
            ifnull(trs.id_ticket_order, 0) AS is_seat_reserved,
            COUNT(trs.id_ticket_order) OVER(PARTITION BY trs.coupe_num) AS is_coupe_not_empty,
            trs.gender_constraints, 
            trs.gender_constraints_vc,
            round(price_basic * k * _route_length) as basic_price    
        from 
            trip_seats as trs
            inner join trip as tr using(id_trip)
            inner join marshrut_confs as mc on (tr.id_marshrut = mc.id_marshrut and trs.vagon_ord_num = mc.vagon_ord_num and trs.seat_num = mc.seat_num)
        where 
            trs.id_trip=_id_trip and trs.id_station=_id_station_a and trs.vagon_ord_num=_vagon_ord_num
    )
    SELECT 
        seat_num,
        name_seat_placement,
        is_seat_reserved,
        basic_price,
        if(is_coupe_not_empty, gender_constraints, gender_constraints_vc) AS gender_constraints
    FROM 
        vagon_seats
    ;
    END
;;

delimiter ;
