
/**
 * ПРОГОЗ ПО РОСТУ ДАННЫХ И СХЕМА АРХИВИРОВАНИЯ.
 *
 * В БД trains основной рост таблиц будет связан либо с добавлением новых поездок в расписание, либо с заказом билетов. Соответственно, это будет касаться таблиц:
 * trip, trip_schedule, trip_seats, ticket_order.
 * Первоначальная идея была создать табличное пространство на отдельном от рабочих таблиц диске для хранения таблице на движке ARCHIVE,
 * которые имеют аналогичную структуру соответствующих рабочих таблиц, которые имеют в своей структуре поле id_trip, и тем самым логически зависят
 * от даты и времени совершаемых поездок.
 * Также нужно было создать процедуру поиска идентификаторов поездок, завершенных на текущую дату, и по ним копировать соответствующие записи 
 * в соответствующие архивные таблицы с последующим удалением. Эту процедуру можно было бы вызывать по расписанию.
 * Структура архивных таблиц и код процедуры приведён ниже.
 *
 * К сожалению, скорость работы процедуры оказалась крайне неудовлетворительной из-за множественных дорогостоящих операций удаления из trip_seats.
 * Данная схема архивации нуждается по всей видимости нуждается в пересмотре. 
 * Как альтернативная идея: партиционировать эти таблицы либо по дате, либо по некоему статусу завершенности, и потом периодически пытаться переносить в архив уже партиции целиком с последующим drop ?
 */

CREATE TABLESPACE archives_tbls 
ADD DATAFILE 'archives_tbls.ibd' 
ENGINE=INNODB;


CREATE TABLE `trip_a` (
  `id_trip` int UNSIGNED NOT NULL COMMENT 'id поездки',
  `date` date NOT NULL COMMENT 'календарная дата начала движения по маршруту',
  `id_marshrut` SMALLINT UNSIGNED NOT NULL COMMENT 'FK, id маршрута'
) 
ENGINE=ARCHIVE 
TABLESPACE=archived_tbls 
COMMENT='Архивный вариант таблицы trip'
;

CREATE TABLE `trip_schedule_a` (
  `id_trip_station` int UNSIGNED NOT NULL,
  `id_trip` int UNSIGNED NOT NULL COMMENT 'FK, id поездки к которой относится данные',
  `id_station` SMALLINT UNSIGNED NOT NULL COMMENT 'FK, станция на маршруте',
  `arrive_dt` datetime DEFAULT NULL COMMENT 'Дата и время отправления от станции',
  `departure_dt` datetime DEFAULT NULL COMMENT 'Дата и время отправления от станции'
) 
ENGINE=ARCHIVE 
TABLESPACE=archived_tbls 
COMMENT='Архивный вариант таблицы trip_schedule'
;

CREATE TABLE `trip_seats_a` (
  `id_trip` int UNSIGNED NOT NULL,
  `id_station` SMALLINT UNSIGNED NOT NULL,
  `vagon_ord_num` TINYINT UNSIGNED NOT NULL,
  `coupe_num` TINYINT UNSIGNED DEFAULT NULL,
  `seat_num` TINYINT UNSIGNED NOT NULL,
  `gender_constraints` TINYINT UNSIGNED DEFAULT NULL,
  `gender_constraints_vc` TINYINT UNSIGNED DEFAULT NULL,
  `id_ticket_order` int UNSIGNED DEFAULT NULL
) 
ENGINE=ARCHIVE 
TABLESPACE=archived_tbls
COMMENT='Архивный вариант таблицы trip_seats'
;

CREATE TABLE `ticket_order_a` (
  `id_ticket_order` int UNSIGNED NOT NULL COMMENT 'PK, кадинальность порядка полутора сотен миллионов в год',
  `ticket_number` CHAR(14) NULL DEFAULT NULL COMMENT 'Номер сформированного электронного билета',
  `id_passenger` int UNSIGNED NOT NULL COMMENT 'FK, id пассажира',
  `id_trip` int UNSIGNED NOT NULL COMMENT 'FK, id поездки из расписания',
  `vagon_ord_num` TINYINT UNSIGNED NOT NULL COMMENT 'Номер вагона',
  `seat_num` TINYINT UNSIGNED NOT NULL COMMENT 'Номер места в вагоне',
  `id_trip_station_a` int UNSIGNED NOT NULL COMMENT 'Начальная станция',
  `id_trip_station_b` int UNSIGNED NOT NULL COMMENT 'Конечная станция',
  `price_itog` SMALLINT UNSIGNED NOT NULL COMMENT 'Итоговая начисленная сумма за билет',
  `status` TINYINT not null default '0' COMMENT 'Статус заказа: 0 - ожидание оплаты, 1 - оплачен, -1 - ожидает возврата денег, -2 - деньги возвращены',
  `order_dt` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `return_dt` DATETIME NULL DEFAULT NULL COMMENT 'Дата и время возврата денег за билет',
  `ticket_number_dt` DATETIME NULL DEFAULT NULL COMMENT 'Дата и время формирования электронного билета'
) 
ENGINE=ARCHIVE 
TABLESPACE=archived_tbls 
COMMENT='Архивный вариант таблицы ticket_order'
;


delimiter ;;

drop procedure if exists archive_old_trips;

create definer='admin'@'%' procedure archive_old_trips(
    out _status smallint,
    out _message varchar(10000) character set utf8mb4 collate utf8mb4_unicode_ci
)
comment 'Перенос в архивные таблицы записей, которые соответствуют завершённым поездкам'
modifies sql data
begin
    declare _now datetime default current_timestamp;
    
    declare exit handler for sqlexception 
    begin  
      rollback;
      get stacked diagnostics condition 1 _status = MYSQL_ERRNO, _message = MESSAGE_TEXT;
    end;
      
    drop temporary table if exists id_trip_finished;
    
    create temporary table id_trip_finished as
        select distinct id_trip 
        from trip_schedule 
        where departure_dt is null and arrive_dt <= _now;
    
    start transaction;
    
        insert into trip_seats_a 
            select * from trip_seats where id_trip in (select id_trip from id_trip_finished);
        
        delete from trip_seats where id_trip in (select id_trip from id_trip_finished);
        
        
        insert into trip_schedule_a 
            select * from trip_schedule where id_trip in (select id_trip from id_trip_finished);
        
        delete from trip_schedule where id_trip in (select id_trip from id_trip_finished);
        
        
        insert into ticket_order_a 
            select * from ticket_order where id_trip in (select id_trip from id_trip_finished);
        
        delete from ticket_order where id_trip in (select id_trip from id_trip_finished);
        
        
        insert into trip_a 
            select * from trip where id_trip in (select id_trip from id_trip_finished);
        
        delete from trip where id_trip in (select id_trip from id_trip_finished);
    
    commit;
    
    set _status = 0;
end
;;

delimiter ;
