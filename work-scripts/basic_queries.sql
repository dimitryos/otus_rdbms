
use trains;

/* Запрос №1.
 * Вывод информации об остановочных пунктах маршрута, соответствующего заданной поездке, с указанием: 
 *   времени прибытия, 
 *   стоянки, 
 *   отбытия, 
 *   времени в пути 
 * (представлен основной запрос из хранимой процедуры get_marshrut_info).
 */
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
  id_trip = 482
ORDER BY 
  order_number
;


/* Запрос №2.
 * Поиск поездов, которые имеют остановки на станциях А и Б, на определенную дату 
 * (представлен основной запрос их хранимой процедуры get_train_variants_info)
 */
set @_id_station_a := 4862;
set @_id_station_b := 1407;
set @_date_trip := cast('2019-02-05' as date);

WITH mrsh_cte AS (
    /* 
     * Получаем список маршрутов, которые содержат как А, так и Б в заданном порядке.
     * Для последующих соединений в том числе паралелльно также выводим: 
     *        id и названия станций,
     *        время в пути между станциями,
     *        id конфигурации состава, который будет отправляться от начальной станции А.
     * По каждому маршруту всю выводимую информацию располагаем в одну строку.
     */
    SELECT 
        ma.id_marshrut, 
        @_id_station_a AS id_station_a,
        (SELECT station_name FROM station WHERE id_station=@_id_station_a) AS station_name_start, 
        TIMEDIFF(mb.reach_time, IFNULL(ma.reach_time, maketime(0,0,0))) AS travel_time,
        @_id_station_b AS id_station_b,
        (SELECT station_name FROM station WHERE id_station=@_id_station_b) AS station_name_end,
        ma.id_sostav_type
    FROM 
        marshrut AS ma CROSS JOIN marshrut AS mb 
    WHERE
        ma.id_marshrut = mb.id_marshrut
        AND ma.id_station = @_id_station_a
        AND mb.id_station = @_id_station_b
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
            WHERE trs.id_trip = tr.id_trip AND trs.id_station = @_id_station_a
        ) AS start_dt,
        mrsh_cte.travel_time,
        (
            SELECT trs.arrive_dt 
            FROM trip_schedule AS trs 
            WHERE trs.id_trip = tr.id_trip AND trs.id_station = @_id_station_b
        ) AS end_dt,
        mrsh_cte.id_sostav_type
    FROM 
        mrsh_cte 
        INNER JOIN marshrut_names AS mn ON mrsh_cte.id_marshrut=mn.id_marshrut
        INNER JOIN train AS t ON mn.id_train=t.id_train
        INNER JOIN trip AS tr ON mrsh_cte.id_marshrut=tr.id_marshrut
    WHERE 
        tr.`date` = @_date_trip
)
/*
 * По каждой поездке присоединяем информацию о задействованных перевозчиках.
 * Применяем группировку с конкатенацией, чтобы вся информация о поезде была в одной строке.
 */
SELECT 
    id_trip, 
    any_value(id_train) AS id_train, 
    /* номер поезда */
    any_value(train_num) AS train_num,
    /* фирменное название поезда (если есть) */
    any_value(train_name) AS train_name,
    /* название начальной станции */
    any_value(station_name_start) AS train_name,
    /* название конечной станции */
    any_value(station_name_end) AS station_name_end,
    /* дата и время отправления от начальной станции */
    any_value(start_dt) AS start_dt,
    /* продолжительность поездки по данному отрезку маршрута */
    any_value(travel_time) AS travel_time,
    /* дата и время прибытия на конечную станцию */
    any_value(end_dt) AS end_dt,
    /* названия перевозчиков в данном составе */
    GROUP_CONCAT(distinct p.NAME) AS perevozchik_name
FROM 
    trains_cte 
    INNER JOIN sostav_conf AS st ON trains_cte.id_sostav_type = st.id_sostav_type
    INNER JOIN vagon_type AS vt ON st.id_vagon_type = vt.id_vagon_type
    INNER JOIN perevozchik AS p ON vt.id_perevozchik = p.id_perevozchik
GROUP BY 
    id_trip
;



set @_id_trip := 482;
select id_marshrut from trip where id_trip = @_id_trip into @_id_marshrut;
/* Запрос №3.
 * Получение списка нижнего порога цен на проезд от А до станции Б для заданной поездки по каждой присутствующей в данном составе категории вагона 
 * с выводом сопутствующей информации (Запросы взяты из хранимой процедуры basic_vagon_prices)
 * (версия для движка MEMORY)
 */
select
    /* Категория вагона (купе, плацкарт и т.п.) */
    any_value(name_vagon_category), 
    /* есть ли в наличии места для инвалидов (0 - если нет) */
    sum(is_invalid) as has_invalid_seats,
    /* есть ли в наличии багажное купе (оно есть только в вагонах, у которых id_vagon_type=29) */
    sum(if(id_vagon_type=29, 1, 0)) as has_heavy_luggage_coupe,
    /* сколько в наличии свободных мест */
    count(*) as vacant_seats_total, 
    /* нижний порог цены */
    min(round(price_basic * k * route_length(@_id_marshrut, @_id_station_a, @_id_station_b))) as price_vagon_itog
from 
    trip_seats as trs
    inner join trip as tr using(id_trip)
    inner join marshrut_confs as mc on (mc.id_marshrut = tr.id_marshrut and mc.vagon_ord_num = trs.vagon_ord_num and mc.seat_num = trs.seat_num)
where 
    trs.id_trip = @_id_trip and trs.id_station = @_id_station_a and id_ticket_order is null
group by
    id_vagon_category
;

/*
 * то же самое (версия, использующая вьюшку)
 */
select
    any_value(name_vagon_category) as name_vagon_category, 
    sum(is_invalid) as has_invalid_seats,
    sum(if(mc.id_vagon_type=29, 1, 0)) as has_heavy_luggage_coupe,
    count(*) as vacant_seats_total, 
    min(round(price_basic * k * route_length(@_id_marshrut, @_id_station_a, @_id_station_b))) as price_vagon_itog
from 
    trip_seats as trs
    inner join trip as tr using(id_trip)
    inner join v_marshrut_confs as mc on (mc.id_marshrut = tr.id_marshrut and mc.vagon_ord_num = trs.vagon_ord_num and mc.seat_num = trs.seat_num)
where 
    trs.id_trip=@_id_trip and trs.id_station=@_id_station_a and trs.id_ticket_order is null 
group by
    mc.id_vagon_category
;


/* Запрос №4.
 * Для заданного отправления и категории вагона выводит общую информацию о ценах и сервисных услугах по каждому номеру вагона в составе соответствующей 
 * категории, в котором есть наличие свободных мест, с группировкой по типу расположения места 
 * (представлен основной запрос из хранимой процедуры basic_vagon_info).
 */
set @_id_vagon_category := 4; /* категория вагона: купе (комфорт) */

select
    /* № вагона */
    trs.vagon_ord_num, 
    /* тип расположения места */
    any_value(name_seat_placement) as placement,
    /* количество свободных мест с данным типом расположения*/
    count(*) AS vacant_seats_qty,
    /* нижний порог цены для данной группы мест */
    min(round(price_basic * k * route_length(@_id_marshrut, @_id_station_a, @_id_station_b))) as price_from, 
    /* название перевозчика, которому принадлежит данный вагон в составе */
    any_value(perevozchik_name) as perevozchik_name, 
    /* класс обслуживания вагона */
    any_value(service_class_code) as service_class_code, 
    /* наличие специального багажного купе */
    sum(if(id_vagon_type=29, 1, 0)) as has_heavy_luggage_coupe,
    /* наличие места для инвалида в данном вагоне */
    sum(is_invalid) as has_invalid_seats,
    /* сервисные услуги, доступные для данного вагона */
    group_concat(distinct so.id_service_option) AS id_service_options
from 
    trip_seats as trs
    inner join trip as tr using(id_trip)
    inner join marshrut_confs as mc on (mc.id_marshrut = tr.id_marshrut and mc.vagon_ord_num = trs.vagon_ord_num and mc.seat_num = trs.seat_num)
    inner join service_class_options AS sco ON mc.id_service_class = sco.id_service_class
    inner join service_option AS so ON sco.id_service_option = so.id_service_option
where 
    trs.id_trip = @_id_trip and trs.id_station = @_id_station_a and id_ticket_order is null and mc.id_vagon_category = @_id_vagon_category
group by 
    vagon_ord_num, id_seat_placement
;


/* Запрос №5.
 * Для заданной поездки, станции отправления и номера вагона вывести список мест с информацией 
 * о цене, месторасположении и ограничениях по полу (представлен основной запрос процедуры vagon_vacant_seats).
 * [Для определения степени заполненности купе используется оконная функция].
 * [Подразумевается, что расстояние между станциями _route_length уже было рассчитано в предыдущих запросах и известно априори].
 */
set @_vagon_ord_num := 3;
set @_route_length := 1000;

WITH vagon_seats AS (
    select 
        trs.coupe_num, /* Номер купе */
        trs.seat_num, /* Номер места */
        name_seat_placement,  /* Расположение места */
        ifnull(trs.id_ticket_order, 0) as is_seat_reserved, /* Место занято? */
        COUNT(trs.id_ticket_order) OVER(PARTITION BY trs.coupe_num) AS is_coupe_not_empty, /* Купе пусто? */
        trs.gender_constraints, /* Действующие гендерные ограничения */ 
        trs.gender_constraints_vc, /* Исходные гендерные ограничения */
        round(price_basic * k * @_route_length) as basic_price /* Основная цена проезда по заданому отрезку маршрута */
    from 
        trip_seats as trs
        inner join trip as tr using(id_trip)
        inner join marshrut_confs as mc on (mc.id_marshrut = tr.id_marshrut and mc.vagon_ord_num = trs.vagon_ord_num and mc.seat_num = trs.seat_num)
    where 
        trs.id_trip = @_id_trip and trs.id_station = @_id_station_a and trs.vagon_ord_num = @_vagon_ord_num
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