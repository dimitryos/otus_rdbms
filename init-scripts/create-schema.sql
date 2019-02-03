DROP DATABASE IF EXISTS trains;

CREATE DATABASE trains 
DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

USE trains;

CREATE TABLE `train` (
  `id_train` SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'первичный ключ (всего в стране курсируют не более 1000 поездов дальнего следования)',
  `train_num` VARCHAR(20) NOT NULL COMMENT 'Номер поезда (символьно-цифровая комбинация, достаточно 5 символов)',
  `train_name` VARCHAR(100) DEFAULT NULL COMMENT 'Фирменное название поезда (достаточно 45 символов, может не существовать)',
  `description` text COMMENT 'Текстовое описание поезда (размер до 65000 символов, необязательное поле)',
  `rating` float UNSIGNED DEFAULT NULL COMMENT 'Рейтинг поезда по 5-балльной шкале на основе оценок пассажиров, оставивших отзыв (среднее арифметическое оценок)',
  PRIMARY KEY (`id_train`)
) 
ENGINE=InnoDB 
COMMENT='Главный перечень поездов с номерами и общими сведениями'
;


CREATE TABLE `passenger` (
  `id_passenger` int UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'id пассажира (беззнаковый, за год осуществляется около 100 млн. заказов)',
  `login` VARCHAR(80) NOT NULL COMMENT 'Логин для входа на сайт системы заказа билетов (обязательное поле, не более 20 символов)',
  `password` VARCHAR(120) NOT NULL COMMENT 'Пароль для входа на сайт системы заказа билетов (обязательное поле, не более 30 символов)',
  `email` VARCHAR(200) NOT NULL COMMENT 'Адрес эл. почты (обязательное поле, достаточно 50 символов)',
  PRIMARY KEY (`id_passenger`),
  UNIQUE KEY `login_uq` (`login`) COMMENT 'Логины пользователей должны быть уникальны',
  UNIQUE KEY `email_uq` (`email`) COMMENT 'Для исключения ситуаций перерегистрации одного и того же пользователя под разными логинами'
) 
ENGINE=InnoDB
COMMENT 'Данные пассажира, не являющиеся персональными'
;


CREATE TABLE `passenger_pdata` (
  `id_passenger` int UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'FK, id пассажира',
  `name` VARCHAR(200) NOT NULL COMMENT 'Имя (достаточно 50 символов)',
  `father_name` VARCHAR(200) DEFAULT NULL COMMENT 'Отчество (необязательное поле, достаточно 50 символов)',
  `family_name` VARCHAR(200) NOT NULL COMMENT 'Фамилия (достаточно 50 символов)',
  `gender` TINYINT UNSIGNED NOT NULL COMMENT 'Пол (возможны только два варианта: 2 - мужской, 3 - женский)',
  `birth_date` DATE NOT NULL COMMENT 'Дата рождения (обычный тип даты)',
  `passport` VARCHAR(60) DEFAULT NULL COMMENT 'Номер удостоверения личности (обязательное поле, для большинства удостоверений достаточно 15 символов)',
  PRIMARY KEY (`id_passenger`),
  UNIQUE KEY `passport_uq` (`passport`) COMMENT 'Номера удостоверений личности должны быть уникальны',
  CONSTRAINT `fk_passenger_id_pdt` FOREIGN KEY (`id_passenger`) REFERENCES `passenger` (`id_passenger`) ON DELETE RESTRICT ON UPDATE CASCADE
) 
TABLESPACE confident_data
ENGINE=InnoDB
COMMENT='Персональные данные пассажира'
;


CREATE TABLE `comments` (
	`id_comment` INT(10) UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'PK, кардинальность может составлять несколько миллионов',
	`id_passenger` INT(10) UNSIGNED NOT NULL COMMENT 'FK, id пассажира, оставившего комментарий',
	`id_train` SMALLINT(5) UNSIGNED NOT NULL COMMENT 'FK, id поезда, к которому относится коммментарий',
	`comment_text` TEXT NOT NULL COMMENT 'Текст комментария примерно до 16 тысяч знаков' COLLATE 'utf8mb4_unicode_ci',
	`rate` TINYINT(4) NULL DEFAULT NULL COMMENT 'Оценка пользователя по 10-бальной шкале',
    `comment_date` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Дата и время размещения отзыва',
    
	PRIMARY KEY (`id_comment`),
	INDEX `fk_passenger_cm` (`id_passenger`),
	INDEX `fk_train_cm` (`id_train`),
	CONSTRAINT `fk_passenger_cm` FOREIGN KEY (`id_passenger`) REFERENCES `passenger` (`id_passenger`) ON UPDATE CASCADE ON DELETE CASCADE,
	CONSTRAINT `fk_train_cm` FOREIGN KEY (`id_train`) REFERENCES `train` (`id_train`) ON UPDATE CASCADE ON DELETE CASCADE
)
COMMENT='Комментарии и рейтинги от пассажиров относительно поездов'
ENGINE=InnoDB
;


CREATE TABLE `perevozchik` (
  `id_perevozchik` TINYINT UNSIGNED NOT NULL,
  `name` VARCHAR(80) NOT NULL COMMENT 'Короткое название перевозчика (достаточно 20 символов)',
  `full_name` VARCHAR(160) NOT NULL COMMENT 'Полное название перевозчика (достаточно 40 символов)',
  
  PRIMARY KEY (`id_perevozchik`)
) 
ENGINE=InnoDB 
COMMENT='Справочник компаний-перевозчиков'
;


CREATE TABLE `railway` (
  `id_railway` TINYINT UNSIGNED NOT NULL COMMENT 'id железной дороги (эквивалентен железнодорожному коду приписки, не превышает 100)',
  
  `name_railway` VARCHAR(160) NOT NULL COMMENT 'Название железной дороги (достаточно 40 символов)',
  PRIMARY KEY (`id_railway`)
) 
ENGINE=InnoDB 
COMMENT='Справочник основных магистральных железных дорог Российской Федерации'
;


CREATE TABLE `vagon_category` (
  `id_vagon_category` TINYINT UNSIGNED NOT NULL COMMENT 'первичный ключ (количество типов вагонов вряд ли превысит даже 20)',
  `name_vagon_category` VARCHAR(120) NOT NULL COMMENT 'Название категории вагона (достаточно 30 символов)',
  
  PRIMARY KEY (`id_vagon_category`)
) 
ENGINE=InnoDB 
COMMENT='Справочник общих категорий вагонов (люкс, СВ, купе, плацкарт и т.п.)'
;


CREATE TABLE `station` (
  `id_station` SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'id станции (общее число станций не превышает 6000 тысяч)',
  `station_name` VARCHAR(200) NOT NULL COMMENT 'Название станции в соответствии с перечнем на сайте Росжелдора (достаточно 50 символов)',
  `station_esr` VARCHAR(30) NOT NULL COMMENT 'код ЕСР станции (как правило, длина составляет не более 6 символов)',
  `id_railway` TINYINT UNSIGNED NOT NULL COMMENT 'Железная дорога, к которой принадлежит станция (FK, тип определяется типом внешнего ключа)',
  
  PRIMARY KEY (`id_station`),
  INDEX `fk_railway_st` (`id_railway`),
  CONSTRAINT `fk_railway_st` FOREIGN KEY (`id_railway`) REFERENCES `railway` (`id_railway`) ON UPDATE CASCADE
) 
ENGINE=InnoDB 
COMMENT='Справочник названий станций на основе данных Росжелдора'
;


CREATE TABLE `marshrut_names` (
  `id_marshrut` SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'PK, id маршрута (примерно равен числу поездов, т.е. несколько сотен)',
  `marshrut_name` VARCHAR(24) CHARACTER SET utf8 NOT NULL COMMENT 'Краткий уникальный символический код маршрута не более 6 символов',
  `description` VARCHAR(500) CHARACTER SET utf8 DEFAULT NULL COMMENT 'Краткое текстовое описание маршрута',
  `id_train` SMALLINT UNSIGNED NOT NULL COMMENT 'FK, id поезда, к которому относится маршрут',
  
  PRIMARY KEY (`id_marshrut`),
  UNIQUE KEY `marshrut_name` (`id_train`, `marshrut_name`) COMMENT 'Каждая связь маршрут-поезд должна быть уникальна. Также этот индекс используется для поддержки внешнего ключа id_train.',
  CONSTRAINT `fk_train_mn` FOREIGN KEY (`id_train`) REFERENCES `train` (`id_train`) ON UPDATE CASCADE
) 
ENGINE=InnoDB 
COMMENT='Общий перечень маршрутов поездов'
;


CREATE TABLE `sostav_type` (
  `id_sostav_type` SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'id состава (кардинальность примерно равна числу поездов (т.е. не более тысячи) с учетом того, что некоторым поездам соответствют несколько типов составов, поскольку они могут изменять тип состава на пути следования)',
  `sostav_name` VARCHAR(100) NOT NULL COMMENT 'Кодовое название состава',
  `description` text COMMENT 'Расширенное описание состава',
  
  PRIMARY KEY (`id_sostav_type`),
  UNIQUE KEY `sostav_name` (`sostav_name`) COMMENT 'Исключение дублирования сведений об одном и том же составе'
) 
ENGINE=InnoDB 
COMMENT='Перечень символических названий кофигураций составов, находящихся в эксплуатации'
;


CREATE TABLE `marshrut` (
  `id_marshrut` SMALLINT UNSIGNED NOT NULL COMMENT 'сост. PK, id маршрута (тж. FK)',
  `id_station` SMALLINT UNSIGNED NOT NULL COMMENT 'сост. PK, id станции остановки (тж. FK)',
  `order_number` TINYINT UNSIGNED NOT NULL COMMENT 'Порядковый номер остановки поезда на данном маршруте',
  `reach_time` TIME DEFAULT NULL COMMENT 'Время в пути от начала маршрута',
  `arrive_time` TIME DEFAULT NULL COMMENT 'Время прибытия на станцию (рассчитывается как сумма departure_time от начальной станции и reach_time до текущей станции по модулю суток (24 часа))',
  `stop_time` TIME DEFAULT NULL COMMENT 'Время стоянки',
  `departure_time` TIME DEFAULT NULL COMMENT 'Время отправления со станции (рассчитывается как сумма reach_time и stop_time для текущей станции по модулю суток (24 часа))',
  `km_from_start` SMALLINT UNSIGNED DEFAULT NULL COMMENT 'Расстояние от начальной станции в километрах',
  `id_sostav_type` SMALLINT UNSIGNED NOT NULL COMMENT 'Актуальный тип состава, отправляющийся от данной станции (FK)',
  
  PRIMARY KEY (`id_marshrut`,`id_station`),
  INDEX `fk_sostav_type_mrsh` (`id_sostav_type`),
  INDEX `idx_station_number` (`id_station`,`order_number`),
  CONSTRAINT `fk_marshrut_id_mrsh` FOREIGN KEY (`id_marshrut`) REFERENCES `marshrut_names` (`id_marshrut`) ON UPDATE CASCADE,
  CONSTRAINT `fk_sostav_type_mrsh` FOREIGN KEY (`id_sostav_type`) REFERENCES `sostav_type` (`id_sostav_type`) ON UPDATE CASCADE,
  CONSTRAINT `fk_station_mrsh` FOREIGN KEY (`id_station`) REFERENCES `station` (`id_station`) ON UPDATE CASCADE
) 
ENGINE=InnoDB 
COMMENT='Основной перечень маршрутов'
;


CREATE TABLE `service_option` (
  `id_service_option` TINYINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Первичный ключ, общее число сервисных опций не превышает нескольких десятков',
  `service_option_name` VARCHAR(600) NOT NULL COMMENT 'Название опции (в отдельных случаях длина может достигать около 150 символов)',
  `description` VARCHAR(2000) DEFAULT NULL COMMENT 'Название опции (в отдельных случаях длина может достигать около 500 символов)',
  
  PRIMARY KEY (`id_service_option`)
) 
ENGINE=InnoDB 
COMMENT='Справочник сервисных услуг'
;


CREATE TABLE `service_class` (
  `id_service_class` TINYINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Первичный ключ, общее число классов обслуживания не превышает нескольких десятков',
  `service_class_code` VARCHAR(80) NOT NULL COMMENT 'Код класса обслуживания (длина, как правило, два символа; у некоторых перевозчиков может достигать до двадцати)',
  `description` VARCHAR(500) DEFAULT NULL COMMENT 'Текстовое примечание (достаточно 125 символов)',
  `id_vagon_category` TINYINT UNSIGNED NOT NULL COMMENT 'FK, категория вагона, к которой относится данный класс обслуживания',
  `id_perevozchik` TINYINT UNSIGNED NOT NULL COMMENT 'FK, перевозчик, который реализует данный класс обслуживания',
  
  PRIMARY KEY (`id_service_class`),
  INDEX `fk_perevozchik_srvc` (`id_perevozchik`),
  INDEX `fk_vagon_category_srvc` (`id_vagon_category`),
  CONSTRAINT `fk_perevozchik_srvc` FOREIGN KEY (`id_perevozchik`) REFERENCES `perevozchik` (`id_perevozchik`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_vagon_category_srvc` FOREIGN KEY (`id_vagon_category`) REFERENCES `vagon_category` (`id_vagon_category`) ON DELETE CASCADE ON UPDATE CASCADE
) 
ENGINE=InnoDB 
COMMENT='Классы обслуживания вагонов по перевозчикам'
;


CREATE TABLE `service_class_options` (
  `id_service_class` TINYINT UNSIGNED NOT NULL,
  `id_service_option` TINYINT UNSIGNED NOT NULL,
  
  UNIQUE KEY `uq_service_class_options` (`id_service_class`,`id_service_option`) COMMENT 'Связи класс-опция не должны дублироваться',
  INDEX `fk_service_option_sco` (`id_service_option`) COMMENT 'Оставлен для поддержки внешнего ключа id_service_option, поскольку ключ uq_service_class_options не может выполнять эту роль',
  CONSTRAINT `fk_service_class_sco` FOREIGN KEY (`id_service_class`) REFERENCES `service_class` (`id_service_class`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_service_option_sco` FOREIGN KEY (`id_service_option`) REFERENCES `service_option` (`id_service_option`) ON DELETE CASCADE ON UPDATE CASCADE
) 
ENGINE=InnoDB 
COMMENT='Сервисные опции в зависимости от класса обслуживания'
;


CREATE TABLE `vagon_type` (
  `id_vagon_type` TINYINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'id типа вагона (примерно равно произведению количества классов вагонов и числа перевозчиков, т.е. около 40)',
  `vagon_type_name` VARCHAR(120) NOT NULL COMMENT 'Название типа вагона (достаточно 30 символов)',
  `id_perevozchik` TINYINT UNSIGNED NOT NULL COMMENT 'FK, id перевозчика)',
  `id_vagon_category` TINYINT UNSIGNED NOT NULL COMMENT 'FK, id категории вагона)',
  `description` VARCHAR(1000) DEFAULT NULL COMMENT 'Примечания (не более 250 символов)',
  
  PRIMARY KEY (`id_vagon_type`),
  UNIQUE KEY `uq_vagon_type_perevozchik` (`vagon_type_name`,`id_perevozchik`) COMMENT 'Тип вагона и его символьное название должны однозначно соответствовать конкретному перевозчику',
  INDEX `fk_vagon_category_vt` (`id_vagon_category`),
  INDEX `fk_perevozchik_vt` (`id_perevozchik`),
  CONSTRAINT `fk_perevozchik_vt` FOREIGN KEY (`id_perevozchik`) REFERENCES `perevozchik` (`id_perevozchik`) ON UPDATE CASCADE,
  CONSTRAINT `fk_vagon_category_vt` FOREIGN KEY (`id_vagon_category`) REFERENCES `vagon_category` (`id_vagon_category`) ON UPDATE CASCADE
) 
ENGINE=InnoDB 
COMMENT='Типы вагонов в соответствии с классификацией перевозчика или категории вагона и класса обслуживания'
;


CREATE TABLE seat_placement (
    `id_seat_placement` TINYINT UNSIGNED NOT NULL,
	`name_seat_placement` VARCHAR(120),
	
	PRIMARY KEY (`id_seat_placement`)
) 
comment 'Справочник вариантов расположения места в вагоне'
ENGINE=INNODB
;

insert into seat_placement values 
(1, 'Нижнее'),
(2, 'Верхнее'),
(3, 'Нижнее боковое'),
(4, 'Верхнее боковое'),
(5, 'Нижнее боковое у туалета'),
(6, 'Последнее купе, нижнее'),
(7, 'Последнее купе, верхнее')
;


CREATE TABLE `vagon_conf` (
  `id_vagon_type` TINYINT UNSIGNED NOT NULL COMMENT 'сост. PK, тип вагона (тж. FK)',
  `seat_num` TINYINT UNSIGNED NOT NULL COMMENT 'сост. PK, номер места в вагоне (не более 125)',
  `coupe_num` TINYINT UNSIGNED DEFAULT NULL COMMENT 'номер купе',
 
 `id_seat_placement` TINYINT UNSIGNED GENERATED ALWAYS AS (
    case
       when ((`id_vagon_type` = 15) and (`seat_num` = 37)) then 5
       when ((`id_vagon_type` = 15) and (`seat_num` between 38 and 51) and ((`seat_num` % 2) = 0)) then 4
       when ((`id_vagon_type` = 15) and (`seat_num` between 39 and 51) and ((`seat_num` % 2) != 0)) then 3
       when ((`id_vagon_type` = 15) and (`seat_num` between 33 and 36) and ((`seat_num` % 2) = 0)) then 7
       when ((`id_vagon_type` = 15) and (`seat_num` between 33 and 36) and ((`seat_num` % 2) != 0)) then 6
       when ((`id_vagon_type` in (3,4,29,30,12,13,14,15)) and ((`seat_num` % 2) = 0)) then 2
       else 1
    end 
  ) VIRTUAL COMMENT 'id типа пространственного расположения места в вагоне. Функционально зависит от перевозчика и номера места.',

  `is_invalid` TINYINT NOT NULL DEFAULT '0' COMMENT 'Признак места, предназначеного для инвалидов',
  `gender_constraints` TINYINT NOT NULL DEFAULT '0' COMMENT 'Гендерное ограничение возможности забронировать место в данном купе в зависимости от пола пассажира: 0 - без различия, 1 - будет определяться динамически полом первого пассажира в данном купе, 2 - мужчины, 3 - женщины.',

  `k` decimal(4,3) UNSIGNED GENERATED ALWAYS AS (
    case 
       when (`is_invalid` = 1) then 0.5 
       when (`id_seat_placement` = 2) then 0.85 
       when (`id_seat_placement` = 3) then 0.85 
       when (`id_seat_placement` = 4) then 0.75 
       when (`id_seat_placement` = 5) then 0.9 
       when (`id_seat_placement` = 6) then 0.9 
       when (`id_seat_placement` = 7) then 0.9 
       else 1.0 
	end
  ) VIRTUAL COMMENT 'Коэффициент к базовой цене в зависимости от пространственного расположения места в вагоне',
  
  PRIMARY KEY (`id_vagon_type`,`seat_num`),
  INDEX `idx_seat_placement_vc` (`id_seat_placement`),
  CONSTRAINT `fk_vagon_type_vc` FOREIGN KEY (`id_vagon_type`) REFERENCES `vagon_type` (`id_vagon_type`) ON UPDATE CASCADE
) 
ENGINE=InnoDB 
COMMENT='Конфигурация мест в вагоне заданного типа'
;


CREATE TABLE `sostav_conf` (
  `id_sostav_type` SMALLINT UNSIGNED NOT NULL COMMENT 'FK, тип состава',
  `vagon_ord_num` VARCHAR(16) CHARACTER SET utf8 NOT NULL COMMENT 'Порядковый номер вагона в составе',
  `id_vagon_type` TINYINT UNSIGNED NOT NULL COMMENT 'FK, тип вагона',
  `id_service_class` TINYINT UNSIGNED NOT NULL COMMENT 'Класс обслуживания вагона',
  `price_basic` decimal(5,3) UNSIGNED NOT NULL COMMENT 'Базовая цена проезда в данном вагоне за 1 км',
  
  UNIQUE KEY `uq_sostav_vagon` (`id_sostav_type`, `vagon_ord_num`) COMMENT 'Исключение дублирования сведений о номере вагона в пределах одного состава. Также может выполнять роль первичного ключа',
  INDEX `fk_vagon_trs` (`id_vagon_type`),
  INDEX `fk_service_trs` (`id_service_class`),
  CONSTRAINT `fk_service_trs` FOREIGN KEY (`id_service_class`) REFERENCES `service_class` (`id_service_class`) ON UPDATE CASCADE,
  CONSTRAINT `fk_sostav_trs` FOREIGN KEY (`id_sostav_type`) REFERENCES `sostav_type` (`id_sostav_type`) ON UPDATE CASCADE,
  CONSTRAINT `fk_vagon_trs` FOREIGN KEY (`id_vagon_type`) REFERENCES `vagon_type` (`id_vagon_type`) ON UPDATE CASCADE
) 
ENGINE=InnoDB 
COMMENT='Конфигурация вагонов для заданного типа состава (связь состав-вагон)'
;


CREATE TABLE `trip` (
  `id_trip` int UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'id поездки',
  `date` date NOT NULL COMMENT 'календарная дата начала движения по маршруту',
  `id_marshrut` SMALLINT UNSIGNED NOT NULL COMMENT 'FK, id маршрута',
  
  PRIMARY KEY (`id_trip`),
  UNIQUE KEY `uq_date_marshrut_tr` (`date`,`id_marshrut`),
  INDEX `fk_marshrut_tr` (`id_marshrut`),
  CONSTRAINT `fk_marshrut_tr` FOREIGN KEY (`id_marshrut`) REFERENCES `marshrut_names` (`id_marshrut`) ON UPDATE CASCADE
) 
ENGINE=InnoDB 
COMMENT='Поездка поезда. Отражает факт начала движения по заданному маршруту на определённую дату.\nЯвляется основой для генерации записей таблицы расширенного расписания по станциям.\nТакже к поездке привязывается заказ билета.'
;


CREATE TABLE `trip_schedule` (
  `id_trip_station` int UNSIGNED NOT NULL AUTO_INCREMENT,
  `id_trip` int UNSIGNED NOT NULL COMMENT 'FK, id поездки к которой относится данные',
  `id_station` SMALLINT UNSIGNED NOT NULL COMMENT 'FK, станция на маршруте',
  `arrive_dt` datetime DEFAULT NULL COMMENT 'Дата и время отправления от станции',
  `departure_dt` datetime DEFAULT NULL COMMENT 'Дата и время отправления от станции',
  
  PRIMARY KEY (`id_trip_station`),
  UNIQUE KEY `id_trip_id_station` (`id_trip`,`id_station`) COMMENT 'Исключение дублирования сведений об одной и той же станции в пределах одной поездки поезда',
  INDEX `fk_station_ts` (`id_station`),
  CONSTRAINT `fk_station_ts` FOREIGN KEY (`id_station`) REFERENCES `station` (`id_station`) ON UPDATE CASCADE,
  CONSTRAINT `fk_trip_ts` FOREIGN KEY (`id_trip`) REFERENCES `trip` (`id_trip`) ON DELETE CASCADE ON UPDATE CASCADE
) 
ENGINE=InnoDB 
COMMENT='Развернутое по станциям расписание отправлений поездов на основе назначенных поездок в расписании trip'
;


CREATE TABLE `trip_seats` (
  `id_trip` int UNSIGNED NOT NULL,
  `id_station` SMALLINT UNSIGNED NOT NULL,
  `vagon_ord_num` TINYINT UNSIGNED NOT NULL,
  `coupe_num` TINYINT UNSIGNED DEFAULT NULL,
  `seat_num` TINYINT UNSIGNED NOT NULL,
  `gender_constraints` TINYINT UNSIGNED DEFAULT NULL,
  `gender_constraints_vc` TINYINT UNSIGNED DEFAULT NULL,
  `id_ticket_order` int UNSIGNED DEFAULT NULL,
  
  INDEX `idx_trip_station_trs` (`id_trip`, `id_station`, `vagon_ord_num`) COMMENT 'Достаточен для большинства запросов к данной таблице',
  INDEX `idx_ticket_order_trs` (`id_ticket_order`) COMMENT 'Используется в триггере при возврате денег за билет, чтобы найти и освободить места, относящиеся к данному заказу'
) 
ENGINE=InnoDB 
COMMENT='Текущий расклад по местам для всех поездок из расписания, включая гендерные ограничения и признаки резервирования. Используется партиционирование по хэшу id поездки для ограничения диапазона сканирования при поиске данных по заданной поездке.'
PARTITION BY HASH (id_trip)
;


CREATE TABLE `ticket_order` (
  `id_ticket_order` int UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'PK, кадинальность порядка полутора сотен миллионов в год',
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
  `ticket_number_dt` DATETIME NULL DEFAULT NULL COMMENT 'Дата и время формирования электронного билета',
  
  PRIMARY KEY (`id_ticket_order`),
  INDEX `fk_passenger_tko` (`id_passenger`),
  INDEX `fk_trip_tko` (`id_trip`),
  CONSTRAINT `fk_trip_tko` FOREIGN KEY (`id_trip`) REFERENCES `trip` (`id_trip`) ON UPDATE CASCADE,
  CONSTRAINT `fk_passenger_tko` FOREIGN KEY (`id_passenger`) REFERENCES `passenger` (`id_passenger`) ON UPDATE CASCADE
) 
ENGINE=InnoDB
COMMENT='Перечень заказов на билет'
;

CREATE TABLE `buh_balance` (
    `id_operation` INT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Первичный ключ (кардинальность может достигать порядка нескольких сотен миллионов в годов)',
    `op_dt` DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT 'Дата и время совершения операции',
    `id_ticket_order` INT UNSIGNED NOT NULL COMMENT 'FK, id заказа билета, к которому относится операция',
    `summa` SMALLINT NOT NULL DEFAULT 0 COMMENT 'Сумма операции (порядка нескольких тысяч рублей без копеек; знак обозначает доход или убыток)',
    
    PRIMARY KEY (`id_operation`, `op_dt`),
    INDEX `fk_tko_bb` (`id_ticket_order`)
) 
COMMENT 'История финансовых операций по заказам билетов'
ENGINE=INNODB
;

/** 
 * Разбиваем таблицу на партиции по году проведения операции и дополнительно каждую партицию делим на секции по хэшу ключа для уменьшения конкуренции за последний блок при вставке 
 */
ALTER TABLE `buh_balance` 
PARTITION BY RANGE (YEAR(op_dt)) 
SUBPARTITION BY LINEAR KEY (`id_operation`) 
SUBPARTITIONS 8
(
    PARTITION g2019 VALUES LESS THAN (2020),
    PARTITION g2020 VALUES LESS THAN (2021),
    PARTITION g2020plus VALUES LESS THAN MAXVALUE 
)
;


/**
 * Справочная вьюшка, чтобы узнать о порядке, названии и id станций всех маршрутов
 */
create algorithm=merge definer=`admin`@`%` sql security definer view v_marhrut_info as
select 
    id_marshrut, order_number, m.id_station, station_name
from 
    marshrut as m inner join station as s using(id_station)
order by 
    id_marshrut, order_number
;

/**
 * Аналог таблицы marshrut_confs в формате вьюшки для сравнения производительности запросов
 */
create algorithm=temptable definer=`admin`@`%` sql security definer view v_marshrut_confs as
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
    inner join sostav_conf as sc using(id_sostav_type)
    inner join vagon_conf as vc on (sc.id_vagon_type=vc.id_vagon_type)
    inner join vagon_type as vt on (vc.id_vagon_type=vt.id_vagon_type)
    inner join vagon_category as vcat using(id_vagon_category)
    inner join service_class AS srvc ON sc.id_service_class=srvc.id_service_class
    inner join perevozchik as p ON vt.id_perevozchik=p.id_perevozchik
	left join seat_placement as sp using(id_seat_placement)
;
