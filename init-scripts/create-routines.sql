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
COMMENT 'Вывод информации об остановочных пунктах маршрута, соответствующего заданной поездке, с указанием времени прибытия, стоянки и отбытия.'
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
         *        id и названия станций,
         *        время в пути между станциями,
         *        id конфигурации состава, который будет отправляться от начальной станции А.
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
        any_value(name_vagon_category), 
        sum(is_invalid) as has_invalid_seats,
        sum(if(id_vagon_type=29, 1, 0)) as has_heavy_luggage_coupe,
        count(*) as vacant_seats_total, 
        min(round(price_basic*k*route_length(_id_marshrut, _id_station_a, _id_station_b))) as price_vagon_itog
    from 
        trip_seats as trs
        inner join trip as tr using(id_trip)
        inner join marshrut_confs as mc on (mc.id_marshrut = tr.id_marshrut and mc.vagon_ord_num = trs.vagon_ord_num and mc.seat_num = trs.seat_num)
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
        inner join v_marshrut_confs as mc on (mc.id_marshrut = tr.id_marshrut and mc.vagon_ord_num = trs.vagon_ord_num and mc.seat_num = trs.seat_num)
    where 
        trs.id_trip=_id_trip and trs.id_station=_id_station_a and trs.id_ticket_order is null 
    group by
        mc.id_vagon_category
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
        inner join marshrut_confs as mc on (mc.id_marshrut = tr.id_marshrut and mc.vagon_ord_num = trs.vagon_ord_num and mc.seat_num = trs.seat_num)
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
            inner join marshrut_confs as mc on (
                mc.id_marshrut = tr.id_marshrut 
                and mc.vagon_ord_num = trs.vagon_ord_num 
                and mc.seat_num = trs.seat_num
            )
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



DROP PROCEDURE if EXISTS place_ticket_order;

CREATE PROCEDURE place_ticket_order (
    IN _id_passenger INT UNSIGNED,
    IN _id_trip INT UNSIGNED,
    IN _id_station_a SMALLINT UNSIGNED,
    IN _id_station_b SMALLINT UNSIGNED,
    IN _vagon_ord_num TINYINT UNSIGNED,
    IN _seat_num TINYINT UNSIGNED,
    IN _wished_gender_constraints TINYINT UNSIGNED,
    IN _price_itog SMALLINT UNSIGNED,
    OUT _id_ticket_order INT UNSIGNED,
    OUT _status SMALLINT,
    OUT _message VARCHAR(10000) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci 
)
MODIFIES SQL DATA
COMMENT 'Размещение заказа на билет на проезд по заданному маршруту'
BEGIN
    /* Разница в сутках между датой отправления поезда и датой размещения заказа */
    DECLARE _trip_date_diff SMALLINT;
    
    /* Скидка (наценка) к базовой цене билета в зависимости от _trip_date_diff */
    DECLARE _time_price_k DECIMAL(4,3);
    
    /* Пол пассажира */
    DECLARE _passenger_gender TINYINT UNSIGNED;
    
    /* Знчения одноименных полей из trip_seats */
    DECLARE _gender_constraints TINYINT UNSIGNED;
    DECLARE _gender_constraints_vc TINYINT UNSIGNED;
    
    /* Порядковые номера граничных станций */
    DECLARE _order_number_a TINYINT UNSIGNED;
    DECLARE _order_number_b TINYINT UNSIGNED;
    
    DECLARE _coupe_num TINYINT UNSIGNED;
    
    /* Признаки занятости места и непустоты купе */
    DECLARE _is_seat_reserved TINYINT UNSIGNED;
    DECLARE _is_coupe_not_empty TINYINT UNSIGNED;
    
    /* Текущее значение из курсора */
    DECLARE _cut_id_station SMALLINT UNSIGNED;
    /* Признак конца выборки данных в курсоре */
    DECLARE cut_end TINYINT UNSIGNED DEFAULT 0;
    
    /* выборка отрезка маршрута от _id_station_a до _id_station_b, соответствующего заданному id_trip, для последующих манипуляций */
    DECLARE cut CURSOR FOR 
        SELECT id_station
        FROM trip AS tr INNER JOIN marshrut USING(id_marshrut)
        WHERE tr.id_trip = _id_trip AND order_number BETWEEN _order_number_a AND _order_number_b
        ORDER BY order_number
    ;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET cut_end=1;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION  
    BEGIN   
        ROLLBACK;
        SET _id_ticket_order = null;
        GET STACKED DIAGNOSTICS CONDITION  1 _status = MYSQL_ERRNO, _message = MESSAGE_TEXT;
    END;

    START TRANSACTION;
    
    /* Вычисляем разницу между датой отправления поезда и датой размещения заказа */
    SELECT DISTINCT datediff(trs.departure_dt, NOW()) AS trip_date_diff
    FROM trip AS tr INNER JOIN trip_schedule AS trs USING(id_trip)
    WHERE tr.id_trip = _id_trip AND trs.arrive_dt IS null
    INTO _trip_date_diff
    ;
    
    /* Вычисляем коэффициент скидки(наценки) в заисимости от разницы между датой отправления поезда и датой размещения заказа*/
    if (_trip_date_diff <= 0 OR _trip_date_diff > 90) then
        SIGNAL SQLSTATE VALUE 'HY000' 
        SET MYSQL_ERRNO = 5003, MESSAGE_TEXT = 'Недопустимая дата для размещения заказа';
    ELSEIF (_trip_date_diff BETWEEN 45 AND 90) then
        SET _time_price_k = 0.8;
    ELSEIF (_trip_date_diff BETWEEN 1 AND 15) then
        SET _time_price_k = (100 + 1.5*(16 - _trip_date_diff))/100;
    ELSE 
        SET _time_price_k = 1.0;
    END if;
    
    /* Выясняем текущее значение гендерных ограничений для заданного места, а также номер соответствующего купе и состояние их занятости */
    WITH vagon_state_by_station AS (
        SELECT 
            trs.*, COUNT(trs.id_ticket_order) OVER(PARTITION BY trs.coupe_num) AS is_coupe_not_empty
        FROM 
            trip_seats AS trs
        WHERE 
            trs.id_trip = _id_trip 
            AND trs.id_station = _id_station_a 
            AND trs.vagon_ord_num = _vagon_ord_num
    )
    SELECT coupe_num, gender_constraints, gender_constraints_vc, id_ticket_order, is_coupe_not_empty
    FROM vagon_state_by_station
    WHERE seat_num = _seat_num
    INTO _coupe_num, _gender_constraints, _gender_constraints_vc, _is_seat_reserved, _is_coupe_not_empty
    ;
    
    if (_is_seat_reserved > 0) then 
        SIGNAL SQLSTATE VALUE 'HY000' 
        SET MYSQL_ERRNO = 5000, MESSAGE_TEXT = 'Данное место уже является зарезервированным';
    END if;
    
    /* Выясняем пол пассажира */
    SELECT pd.gender
    FROM passenger AS p INNER JOIN passenger_pdata AS pd USING(id_passenger) 
    WHERE p.id_passenger = _id_passenger
    INTO _passenger_gender
    ; 
    
    /* Проверяем здравый смысл для накладываемых пассажиром гендерных ограничений: они либо должны соответствовать полу пассажира, либо иметь тип смешанный */
    IF (_wished_gender_constraints != _passenger_gender AND _wished_gender_constraints != 0) THEN
        SIGNAL SQLSTATE VALUE 'HY000' 
        SET MYSQL_ERRNO = 5001, MESSAGE_TEXT = 'Несоответствие пола пассажира типу накладываемых им гендерных ограничений';
    END if;
    
    /* Условия возможности размещения заказа относительно гендерных ограничений: 
          текущий режим не определен, 
          или динамический, 
          или смешанный 
          или совпадает с полом пассажира */
    IF (
        _gender_constraints IS NULL 
        OR _gender_constraints = 0 
        OR _gender_constraints = 1 
        OR _gender_constraints = _passenger_gender
    ) THEN 
        /* Создаём запись о заказе и выясняем его id */
        INSERT INTO ticket_order
        (id_passenger, id_trip, vagon_ord_num, seat_num, id_trip_station_a, id_trip_station_b, price_itog)
        VALUES 
        (_id_passenger, _id_trip, _vagon_ord_num, _seat_num, _id_station_a, _id_station_b, round(_price_itog*_time_price_k));
        
        SET _id_ticket_order = LAST_INSERT_ID();
        
        /* Далее для всех станций заданного отрезка маршрута кроме последней (поскольку пассажир на ней выходит, и место особождается) нужно
           проставить признак резервирования в виде _id_ticket_order, а для всего купе - желаемые пассажиром гендерные ограничения согласно бизнес-правилам */
         
        /* выясняем границы отрезка маршрута */
        SELECT m.order_number
        FROM trip AS tr INNER JOIN marshrut AS m USING(id_marshrut)
        WHERE tr.id_trip=_id_trip AND m.id_station=_id_station_a
        INTO _order_number_a
        ;
        
        SELECT m.order_number
        FROM trip AS tr INNER JOIN marshrut AS m USING(id_marshrut)
        WHERE tr.id_trip=_id_trip AND m.id_station=_id_station_b
        INTO _order_number_b
        ;
        
        OPEN cut;
        
        fetch_cut: LOOP
            FETCH FROM cut INTO _cut_id_station;
            /* Должны выйти из цикла как только достигнем конечной станции заданного отрезка маршрута */
            IF (_cut_id_station = _id_station_b OR cut_end = 1) THEN
                leave fetch_cut;
            END if;
            
            /* Проставляем признак зарезервированности для указанного места в вагоне */
            UPDATE trip_seats AS trs
            SET trs.id_ticket_order = _id_ticket_order
            WHERE 
                trs.id_trip = _id_trip 
                AND trs.id_station = _cut_id_station 
                AND trs.vagon_ord_num = _vagon_ord_num 
                AND trs.seat_num = _seat_num
            ;
                
            /* Гендерные ограничения для купе назначаются первым пассажиром в купе, в случае если на данное купе изначально распостраняется эта возможность */
            IF (_is_coupe_not_empty = 0 AND _gender_constraints_vc = 1) THEN 
                UPDATE trip_seats AS trs
                SET trs.gender_constraints = _wished_gender_constraints
                WHERE 
                    trs.id_trip = _id_trip 
                    AND trs.id_station = _cut_id_station 
                    AND trs.vagon_ord_num = _vagon_ord_num 
                    AND trs.coupe_num = _coupe_num
                ;
            END IF;
        END LOOP fetch_cut;
        
        CLOSE cut;
    ELSE
        SIGNAL SQLSTATE VALUE 'HY000' 
        SET MYSQL_ERRNO = 5002, MESSAGE_TEXT = 'Пол пассажира не соответствует гендерным ограничениям для данного места';    
    END IF;
    
    COMMIT;
END
;;


DROP PROCEDURE if EXISTS place_ticket_return_request;

CREATE PROCEDURE place_ticket_return_request (
    in _id_ticket_order int unsigned,
    out _status smallint,
    out _message varchar(10000)
)
MODIFIES SQL DATA
COMMENT 'Разместить запрос на возврат билета по заказу _id_ticket_order'
BEGIN
    declare _id_trip int unsigned;
    
    declare exit handler for sqlexception  
    begin   
        rollback;
        get stacked diagnostics condition  1 _status = MYSQL_ERRNO, _message = MESSAGE_TEXT;
    end;
    
    START TRANSACTION;
    
    select id_trip 
    from ticket_order 
    where id_ticket_order = _id_ticket_order
    into _id_trip;
    
    /* Проставляем статус «ожидает возврата денег»*/
    update ticket_order
    set `status` = -1, `return_dt` = current_timestamp
    where id_ticket_order = _id_ticket_order;
    
    /* Освобождаем место, соответствующее данному заказу */
    update trip_seats
    set id_ticket_order = null
    where id_trip = _id_trip and id_ticket_order = _id_ticket_order
    ;
    
    COMMIT;
    
    set _status = 0;
END
;;


/* Триггер внесения записи о финансовой операции, связанной с оплатой или возвратом денежных средств по заказу на билет */
DROP TRIGGER if EXISTS `tko_status_bu`;

CREATE TRIGGER `tko_status_bu`
BEFORE UPDATE ON `ticket_order`
FOR EACH ROW 
BEGIN
     /* Время отправления поезда */
    DECLARE _departure_dt DATETIME;
    
    /* Разница в часах между датой отправления поезда и датой размещения заказа на возврат */
    DECLARE _return_time_diff SMALLINT;
    
    /* Коэффициент суммы возврата в зависимости от _return_time_diff */
    DECLARE _return_summa_k DECIMAL(4,3);
    
    /* Если пришли деньги за билет */
    if (OLD.`status` != NEW.`status` and NEW.`status` = 1) then
        INSERT INTO buh_balance (id_ticket_order, summa) VALUES (NEW.id_ticket_order, NEW.price_itog);
    /* Если нужно вернуть деньги за билет */
    ELSEIF (OLD.`status` != NEW.`status` and NEW.`status` = -2) then
        SELECT departure_dt
        FROM trip_schedule 
        WHERE id_trip = NEW.id_trip AND id_station = NEW.id_trip_station_a
        INTO _departure_dt;
        
        SET _return_time_diff = HOUR(TIMEDIFF(_departure_dt, OLD.return_dt));
        /* INSERT INTO debug VALUES(CONCAT('_return_time_diff: ', _return_time_diff)); */
        
        /* Рассчитываем коэффициент для возвращаемой пассажиру суммы в зависимости от момента подачи заявки на возврат билета и времени отправления поезда. 
           Суммы по возвратам заносятся со знаком минус. */
        IF (_return_time_diff > 8) THEN
            SET _return_summa_k = -1.0;
        ELSEIF (_return_time_diff BETWEEN 3 AND 8) THEN
            SET _return_summa_k = -0.7;
        ELSEIF (_return_time_diff BETWEEN -12 AND 2) THEN
           SET _return_summa_k = -0.5;
        ELSE 
           SET _return_summa_k = 0;
        END if;
        
        /* вставляем соответствующую запись, применяя коэффициент перерасчёта */
        INSERT INTO buh_balance 
        (id_ticket_order, summa) 
        VALUES 
        (NEW.id_ticket_order, round(NEW.price_itog * _return_summa_k));
    END if;
END
;;


DROP PROCEDURE if EXISTS gen_electron_ticket;

CREATE PROCEDURE gen_electron_ticket (
    in _id_ticket_order int unsigned,
    out _status smallint,
    out _message varchar(10000)
)
MODIFIES SQL DATA
COMMENT 'Выборка сведений, необходимых для формирования электронного билета по заказу _id_ticket_order'
BEGIN
    declare _tko_status tinyint;
    declare _ticket_number char(14);
    declare _ticket_number_dt datetime;
    declare _fio varchar(250);
    declare _name_vagon_category varchar(120);
    declare _vagon_ord_num tinyint unsigned;
    declare _seat_num tinyint unsigned;
    declare _name_seat_placement varchar(120);
    declare _service_class_code varchar(80);
    declare _train_num varchar(20);
    declare _perevozchik_name varchar(80);
    declare _price_itog smallint unsigned;
    declare _trip_year char(4);
    declare _dep_date varchar(20);
    declare _dep_time varchar(20);
    declare _start_station_name varchar(200);
    declare _end_station_name varchar(200);
    declare _arrive_date varchar(20);
    declare _arrive_time varchar(20);
    
    declare exit handler for sqlexception  
    begin   
        rollback;
        get stacked diagnostics condition  1 _status = MYSQL_ERRNO, _message = MESSAGE_TEXT;
    end;
    
    START TRANSACTION;
    
    select `status` 
    from ticket_order 
    where id_ticket_order = _id_ticket_order 
    into _tko_status;
    
    if (_tko_status !=1 ) then
        SIGNAL SQLSTATE VALUE 'HY000' 
        SET MYSQL_ERRNO = 5005, MESSAGE_TEXT = 'Недопустимый статус заказа';
    end if;
    
    select
        concat(pd.family_name, ' ', left(pd.`name`, 1), ' ', left(pd.father_name, 1)),
        mc.name_vagon_category, 
        tko.vagon_ord_num, 
        tko.seat_num, 
        mc.name_seat_placement,
        mc.service_class_code,
        train_num,
        mc.perevozchik_name,
        tko.price_itog
    from 
        ticket_order as tko
        inner join passenger_pdata as pd using(id_passenger)
        inner join trip as tr using(id_trip)
        inner join marshrut_confs as mc on (
            mc.id_marshrut = tr.id_marshrut
            and mc.vagon_ord_num = tko.vagon_ord_num
            and mc.seat_num = tko.seat_num
        )
    where
        tko.id_ticket_order = _id_ticket_order 
    into
        _fio, _name_vagon_category, _vagon_ord_num, _seat_num, _name_seat_placement, _service_class_code, _train_num, _perevozchik_name, _price_itog
    ;
    
    select
        YEAR(tsc.departure_dt),
        date_format(DATE(tsc.departure_dt), '%d.%m'),
        time_format(TIME(tsc.departure_dt), '%H:%i'),
        st.station_name
    from 
        ticket_order as tko 
        inner join trip_schedule as tsc on (tsc.id_trip=tko.id_trip and tsc.id_station=tko.id_trip_station_a)
        inner join station as st on (tsc.id_station=st.id_station)
    where
        tko.id_ticket_order = _id_ticket_order
    into
        _trip_year, _dep_date, _dep_time, _start_station_name
    ;
    
    select
        date_format(DATE(tsc.arrive_dt), '%d.%m'),
        time_format(TIME(tsc.arrive_dt), '%H:%i'),
        st.station_name as start_station_name
    from 
        ticket_order as tko 
        inner join trip_schedule as tsc on (tsc.id_trip = tko.id_trip and tsc.id_station = tko.id_trip_station_b)
        inner join station as st on (tsc.id_station = st.id_station)
    where
        tko.id_ticket_order = _id_ticket_order
    into
        _arrive_date, _arrive_time, _end_station_name
    ;
    
    set _ticket_number_dt = NOW();
    set _ticket_number = date_format(_ticket_number_dt, '%Y%m%d%H%i%s');
    
    update ticket_order
    set ticket_number = _ticket_number, ticket_number_dt = _ticket_number_dt
    where id_ticket_order = _id_ticket_order;
    
    COMMIT;
    
    select 
        _ticket_number,
        _fio, 
        _trip_year,
        _dep_date,
        _dep_time,
        _start_station_name,
        _arrive_date,
        _arrive_time, 
        _end_station_name,
        _train_num, 
        _vagon_ord_num, 
        _name_vagon_category, 
        _seat_num, 
        _name_seat_placement, 
        _service_class_code, 
        _perevozchik_name, 
        _price_itog,
        date_format(_ticket_number_dt, '%d.%m.%Y %H:%i') as _ticket_number_dt
   ;
END
;;


drop procedure if exists place_comment;

create procedure place_comment (
    in _id_passenger int unsigned,
    in _id_train smallint unsigned,
    in _comment text,
    in _rate tinyint,
    
    out _id_comment int unsigned,
    out _status smallint,
    out _message varchar(10000)
)
modifies sql data
comment 'Размещение отзыва пассажира на поездку в конкретном поезде'
begin
    declare _train_rating float;

    declare exit handler for sqlexception  
    begin   
        rollback;
        get stacked diagnostics condition  1 _status = MYSQL_ERRNO, _message = MESSAGE_TEXT;
    end;
    
    START TRANSACTION;
    
    /* Сначала проверяем, действительно ли этот пассажир имел когда-либо поездку на данном поезде */
    if (not exists(
        select 1
        from 
            ticket_order as tko 
            inner join trip as tr using(id_trip)
            inner join marshrut_confs as mc using(id_marshrut)
        where 
            tko.id_passenger = _id_passenger and tko.`status` = 1 and mc.id_train = _id_train
    )) then 
        /* set _message = concat('Поездок пассажира id=', ifnull(_id_passenger, "NULL"), ' на поезде id=', ifnull(_id_train, "NULL"), ' не существует'); */
        signal sqlstate value 'HY000' 
        set MYSQL_ERRNO = 5006, MESSAGE_TEXT = 'Поездок пассажира на данном поезде не существует';
    end if;
    
    if (_rate not between 1 and 10) then
        signal sqlstate value 'HY000' 
        set MYSQL_ERRNO = 5007, MESSAGE_TEXT = 'Значение данного рейтинга не входит в диапазон 10-бальной шкалы';
    end if;
    
    /* Создаём запись о новом комментарии */
    insert into comments (id_passenger, id_train, comment_text, rate) 
    values (_id_passenger, _id_train, _comment, _rate);
    
    set _id_comment = last_insert_id();
    
    /* Вычисляем текущий рейтинг указанного поезда и обновляем его */
    select avg(rate)
    from comments 
    where id_train = _id_train
    into _train_rating;
    
    update train
    set rating = _train_rating
    where id_train = _id_train;
    
    COMMIT;
    
    set _status = 0;
end
;;

delimiter ;
