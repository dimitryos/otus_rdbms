delimiter ;;

DROP PROCEDURE if EXISTS get_marshrut_info;

CREATE PROCEDURE get_marshrut_info(
	IN _id_trip INT UNSIGNED
)
COMMENT 'Вывод списка возможных вариантов поездов, следующих по заданному маршруту от станции А до станции Б на определенную дату с сопутсвующей информацией'
READS SQL DATA
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
COMMENT 'Вывод списка возможных вариантов поездов, следующих по заданному маршруту от станции А до станции Б на определенную дату с сопутсвующей информацией'
READS SQL DATA
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
	IN _route_length SMALLINT UNSIGNED
)
COMMENT 'Вывод списка возможных вариантов поездов, следующих по заданному маршруту от станции А до станции Б на определенную дату с сопутсвующей информацией'
READS SQL DATA
BEGIN
    select
        name_vagon_category, 
        sum(is_invalid) as has_invalid_seats,
        sum(if(id_vagon_type=29, 1, 0)) as has_heavy_luggage_coupe,
        count(*) as vacant_seats_total, 
        min(round(price_basic*k*_route_length)) as price_vagon_itog
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

delimiter ;
