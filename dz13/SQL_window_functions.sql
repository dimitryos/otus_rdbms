USE sakila;

/* Задание 1.*/

SELECT 
    f.film_id,
    LEFT(f.title, 1) AS f_l,
    f.title,
    f.description,
    f.release_year,
    
    /* пронумеруйте записи по названию фильма, так чтобы при изменении буквы алфавита нумерация начиналась заново */
    row_number() over(PARTITION BY LEFT(f.title, 1) ORDER BY f.film_id) AS f_l_numbering,
    
    /* посчитайте общее количество фильмов и выведете полем в этом же запросе */
    COUNT(*) OVER() AS rows_total,
    
    /* посчитайте общее количество фильмов в зависимости от буквы начала называния фильма */
    COUNT(*) OVER(PARTITION BY LEFT(f.title, 1)) AS f_l_count,
    
    /* следующий ид фильма на следующей строки и включите в выборку */
    lead(f.film_id) over() AS next_film_id,
    
    /* предыдущий ид фильма */
    lag(f.film_id) over() AS prev_film_id,
    
    /* названия фильма 2 строки назад */
    lag(f.title, 2) over() AS second_prev_film_title
FROM 
    film AS f
;


/* Задание 2. */

SELECT
    NTILE(100) over(ORDER BY f.rental_rate DESC, f.`length`) film_groups,
    f.film_id, 
    f.title, 
    fc.category_id, 
    f.rental_rate,
    f.`length`
FROM 
    film AS f
    INNER JOIN film_category AS fc ON fc.film_id=f.film_id
;

/* Задание 3. */

/* С использованием аналитической функции. 
 *
 * Поскольку в исходных данных по каждому сотруднику творится большая неоднозначность с последней датой проката,
 * то пришлось использовать предварительно group_concat.
 */
WITH staff_rentals AS (
    SELECT
        s.staff_id, 
        ANY_VALUE(s.last_name) AS staff_name, 
        r.rental_date, 
        GROUP_CONCAT(c.customer_id) AS customer_ids  
    FROM 
        staff AS s
        INNER JOIN rental AS r ON r.staff_id=s.staff_id
        INNER JOIN customer AS c ON c.customer_id=r.customer_id
    GROUP BY 
        s.staff_id, r.rental_date
)
SELECT DISTINCT 
    staff_id, 
    staff_name, 
    first_value(rental_date) over(PARTITION BY staff_id ORDER BY rental_date desc),
    first_value(customer_ids) over(PARTITION BY staff_id ORDER BY rental_date desc)
FROM 
    staff_rentals
;

/* без использования аналитической функции */
SELECT
    s.staff_id, 
    any_value(s.last_name) AS staff_name, 
    max(r.rental_date) AS max_rental_date, 
    group_concat(c.customer_id) AS customer_ids  
FROM 
    staff AS s
    INNER JOIN rental AS r ON r.staff_id=s.staff_id
    INNER JOIN customer AS c ON c.customer_id=r.customer_id
GROUP BY 
    s.staff_id
;


/* Задание 4. */

/* С использованием аналитической функции */

SELECT DISTINCT 
    a.actor_id, 
    CONCAT(any_value(a.first_name), ' ', any_value(a.last_name)) AS actor_name,
    fa.film_id, 
    ANY_VALUE(f.title) AS film_title,
    MAX(r.rental_date) OVER(PARTITION BY a.actor_id, fa.film_id) AS last_rental_date
FROM 
    actor AS a
    INNER JOIN film_actor AS fa ON fa.actor_id=a.actor_id
    INNER JOIN film AS f ON f.film_id=fa.film_id
    INNER JOIN inventory AS i ON fa.film_id=i.film_id
    INNER JOIN rental AS r ON r.inventory_id=i.inventory_id  
;

/* без использования аналитической функции */
SELECT 
    a.actor_id, CONCAT(any_value(a.first_name), ' ', any_value(a.last_name)) AS actor_name,
    fa.film_id, ANY_VALUE(f.title) AS film_title,
    MAX(r.rental_date) AS last_rental_date
FROM 
    actor AS a
    INNER JOIN film_actor AS fa ON fa.actor_id=a.actor_id
    INNER JOIN film AS f ON f.film_id=fa.film_id
    INNER JOIN inventory AS i ON fa.film_id=i.film_id
    INNER JOIN rental AS r ON r.inventory_id=i.inventory_id  
GROUP BY 
    a.actor_id, fa.film_id
ORDER BY
    a.actor_id, fa.film_id
;