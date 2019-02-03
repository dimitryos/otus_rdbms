/* Вывести текущее состояние мест в вагоне №1 для всех станций маршрута, соответствующего поездке с id_trip=458 */
SELECT trs.*
FROM 
    trip_seats AS trs 
    INNER JOIN trip AS tr USING(id_trip)
    INNER JOIN marshrut AS m ON (m.id_marshrut=tr.id_marshrut AND m.id_station=trs.id_station)
WHERE 
    trs.id_trip=458 AND trs.vagon_ord_num=1
ORDER BY 
    trs.id_trip, m.order_number, trs.vagon_ord_num, trs.seat_num
;

/* Разместить от пассажира с id_passenger=4 заказ на билет по маршруту, соответствующего поездке с id_trip=458, 
   от id_station_a=4862 (Москва-Ярославская) до id_station_b=1374 (Вологда), 
   в 1-й вагон 3-е место с желаемым гендерным ограничением на купе - 2 (мужское), 
   основная цена за билет 1799 руб. (будет перерасчитана в процедуре с учётом величины временного промежутка до отправления поезда) */
CALL place_ticket_order(4, 458, 4862, 1374, 1, 3, 2, 1799, @id_tko, @st, @msg);
SELECT @id_tko, @st, @msg;

/* Если деньги поступили */
UPDATE ticket_order
SET `status` = 1
WHERE id_ticket_order = @id_tko;
COMMIT;
/* При этом должен отработать триггер tko_status_au, который добавит соответствующую запись в buh_balance */


/* Формирование сведений для электронного билета */
CALL gen_electron_ticket(@id_tko, @st, @msg);
SELECT @st, @msg;


/* Добавление комментария от пассажира */
CALL place_comment(4, 8, 'Хороший поезд', 9, @id_comment, @st, @msg);
SELECT @id_comment, @st, @msg;


CALL place_ticket_order(5, 458, 4862, 1407, 1, 13, 3, 8220, @id_tko, @st, @msg);
SELECT @id_tko, @st, @msg;

UPDATE ticket_order
SET `status` = 1
WHERE id_ticket_order = @id_tko;
COMMIT;

CALL place_comment(5, 8, 'Нормальный поезд', 7, @id_comment, @st, @msg);
SELECT @id_comment, @st, @msg;



CALL place_ticket_order(7, 458, 4862, 1407, 1, 2, 2, 1799, @id_tko, @st, @msg);
SELECT @id_tko, @st, @msg;

UPDATE ticket_order
SET `status` = 1
WHERE id_ticket_order = @id_tko;
COMMIT;

/* Если произошёл возврат */
UPDATE ticket_order
SET `status` = -2
WHERE id_ticket_order = @id_tko;
COMMIT;
/* При этом должен отработать триггер tko_status_au с бизнес-логикой возврата */
