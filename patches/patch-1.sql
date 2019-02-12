/**
 * Процедура добавления поездки в расписание.
 *
 * Логика транзакции:
 * 1) проверить корректность входных данных;
 * 2) вставить запись о поездке в таблицу trip и получить её идентификатор id_trip;
 * 3) на основании сведений о маршруте из marshrut и идентификатора id_trip дополнить trip_schedule записями о дате и времени прибытия/отправления постанционно;
 *    а) выяснить порядковый номер конечной станции маршрута,
 *    б) вычислить дату и время начала движения по маршруту,
 *    в) на основании этих сведений в цикле по каждой станции маршрута вычислить время прибытия и отправления,
 *    г) добавить запись с полученными сведениями в таблицу расписания trip_schedule.
 * 4) Добавить в таблицу trip_seats для каждой станции данной поездки основные сведения о составе и состоянии мест в вагонах состава
 *    в том числе - с указанием гендерных ограничений.
 */
delimiter ;;

drop procedure if exists add_trip_schedule;

create definer='admin'@'%' procedure add_trip_schedule(
    in _id_marshrut smallint unsigned,
    in _date date,
    out _id_trip int unsigned,
    out _status smallint,
    out _message varchar(10000) character set utf8mb4 collate utf8mb4_unicode_ci
)
comment 'Помещает в расписание на определенную дату поездку по заданному маршруту'
modifies sql data
begin
    declare _current_id_station smallint unsigned;
    declare _current_order_number tinyint unsigned;
    declare _last_station_order_number tinyint unsigned;
    declare _current_reach_time time;
    declare _current_stop_time time;
    declare _start_trip_dt datetime;
    declare _arrive_dt datetime;
    declare _departure_dt datetime;
    
    /* Курсор для выборки сведений по данному маршруту */
    declare loop_done tinyint default 0;
    declare get_marshrut_id_station cursor for 
        select id_station, order_number, reach_time, stop_time
        from marshrut 
        where id_marshrut = _id_marshrut
        order by order_number;
    declare continue handler for not found set loop_done = 1;
    
    declare exit handler for sqlexception 
      begin  
          rollback;
          set _id_trip = null;
          get stacked diagnostics condition 1 _status = MYSQL_ERRNO, _message = MESSAGE_TEXT;
      end;
    
    start transaction;
    
    if (not exists(select 1 from marshrut where id_marshrut=_id_marshrut)) then
      signal sqlstate value 'HY000' set MYSQL_ERRNO = 1032, MESSAGE_TEXT = 'no such id_marshrut';
    end if;
    
    if (exists(select 1 from trip where id_marshrut=_id_marshrut and `date`=_date)) then
        signal sqlstate value 'HY000' set MYSQL_ERRNO = 5007, MESSAGE_TEXT = 'such trip already exists';
    end if;
    
    insert into trip (`date`, id_marshrut) values (_date, _id_marshrut);
    set _id_trip = last_insert_id();
    
    /* заполняем trip_schedule */
    
    /* порядковый номер последней станции заданного маршрута */
    select distinct order_number 
    from marshrut 
    where id_marshrut = _id_marshrut 
    order by order_number desc limit 1
    into _last_station_order_number;
    
    open get_marshrut_id_station;
    repeat_loop: repeat
       fetch from get_marshrut_id_station into _current_id_station, _current_order_number, _current_reach_time, _current_stop_time;
       
       if (_current_order_number = 1) then 
           set _arrive_dt = null; 
           /* Время отправления от первой по порядку станции находится для неё в поле reach_time */
           set _departure_dt = addtime(_date, _current_reach_time); 
           /* Дата и время начала поездки */
           set _start_trip_dt = _departure_dt;
       else
           /* Для прочих станций поле reach_time имеет смысл времени в пути от первой станции. 
              Время прибытия рассчитывается как сумма даты-времени начала поездки и времени в пути до текущей станции. */
           set _arrive_dt = addtime(_start_trip_dt, _current_reach_time);
           
           /* Время отправления рассчитывается как сумма даты-времени прибытия на текущюю станцию и времени стоянки. */
           set _departure_dt = addtime(_arrive_dt, _current_stop_time);
       end if;
       
       insert into trip_schedule
       (id_trip, id_station, arrive_dt, departure_dt) 
       values 
       (_id_trip, _current_id_station, _arrive_dt, _departure_dt);
       
       /* После добавления сведений о последней станции выходим из цикла */
       if (_current_order_number = _last_station_order_number) then 
           set loop_done = 1; 
       end if;
    until loop_done
    end repeat repeat_loop;
    close get_marshrut_id_station;
    
    /* заполняем trip_seats */
    insert into trip_seats
       (id_trip, id_station, vagon_ord_num, coupe_num, seat_num, gender_constraints_vc)
    select distinct
        id_trip, id_station, sc.vagon_ord_num, coupe_num, vc.seat_num, vc.gender_constraints
    from 
        trip as tr
        inner join marshrut as m using(id_marshrut)
        inner join sostav_conf as sc using(id_sostav_type)
        inner join vagon_conf as vc using(id_vagon_type)
    where
        id_trip = _id_trip
    ;
    
    set _status = 0;
    commit;
end
;;


/* Триггер подержка консистентности расписания trip_schedule в случае обновления marshrut.reach_time */
drop trigger if exists `reach_time_bu`;

create trigger `reach_time_bu`
before update on `marshrut`
for each row 
begin
    declare _tdiff time;
    
    if (OLD.reach_time != NEW.reach_time) then
        /* вычислить разницу во времени между новым и старым занчением reach_time */
        set _tdiff = timediff(NEW.reach_time, OLD.reach_time);
        
        /* Применить вычисленную разницу ко всем поездкам из расписания, относящимся к данному маршруту */
        update 
            trip_schedule
        set 
            arrive_dt = addtime(arrive_dt, _tdiff),
            departure_dt = addtime(departure_dt, _tdiff)
        where
            id_trip in (select id_trip from trip where id_marshrut = OLD.id_marshrut) and 
            id_station = OLD.id_station;
    end if;
end
;;

delimiter ;
