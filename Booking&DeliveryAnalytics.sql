-- CaseStudy

-- 1.Provide a query with the number of bookings per week per retail country
  
--2.Provide a query with the first workshop entry per week per retail country
--  with average associated lead time from booking to the first workshop entry

--3.Provide a query for the computation per week per retail country of:
--  number of bookings
--  Deliveries to the first workshop
--  Associated: lead time of those deliveries ( from booking to first workshop entry)
--  Backlog: cars that, at the end of a given week, were booked and not yet delivered to the first workshop
--  age of backlog

-- Before writing the queries, I performed some exploratory analysis to understand the data better. The query for this is below the Task.
-- I added new columns with the `DATE` type and populated them using data from the existing date columns. 
-- This ensures consistent and accurate date handling for comparisons, calculations, and optimized query performance.



-- Question 3

WITH Bookings AS (
-- Number of bookings (answers question 1)
  SELECT
    dg.week,
    cd.retail_country,
    COUNT(cd.id) AS number_of_bookings
  FROM
    car_data cd
  JOIN
    daily_grid dg ON cd.new_booking_date = dg.new_day
  GROUP BY
    dg.week, cd.retail_country
),
Deliveries AS (
 -- Deliveries to the first workshop (part of question 2)
  SELECT
    dg.week,
    cd.retail_country,
    COUNT(td.car_id) AS deliveries_to_first_workshop,
    AVG(td.new_delivery_date - cd.new_booking_date) AS lead_time_deliveries
  FROM
    car_data cd
  JOIN
    transport_data td ON cd.id = td.car_id
  JOIN
    daily_grid dg ON td.new_delivery_date = dg.new_day
  WHERE
    td.status = 3  AND td.new_delivery_date >= cd.new_booking_date
  GROUP BY
    dg.week, cd.retail_country
),
Backlog AS (  
 -- Backlog (part of question 2)
  SELECT
    dg.week,
    cd.retail_country,
    COUNT(cd.id) AS backlog,
    AVG(dg.new_day - cd.new_booking_date) AS age_of_backlog
  FROM
    car_data cd
  JOIN
    daily_grid dg ON dg.new_day >= cd.new_booking_date
  LEFT JOIN
    transport_data td ON cd.id = td.car_id AND td.status = 3 AND td.new_delivery_date <= dg.new_day -- to make sure lead time is correct 
  WHERE
    td.car_id IS NULL
  GROUP BY
    dg.week, cd.retail_country
), 
Cancellations AS ( -- additional KPI (the number of cancellations per week per retail country)
    SELECT
      dg.week,
      td.start_country AS retail_country,
      COUNT(td.car_id) AS number_of_cancellations
    FROM
      transport_data td
    JOIN
      daily_grid dg ON td.new_canceled_date = dg.new_day
    WHERE
      td.status = 4
    GROUP BY
      dg.week, td.start_country
)
SELECT
  b.week,
  b.retail_country,
  b.number_of_bookings AS number_of_bookings,
  d.deliveries_to_first_workshop AS deliveries_to_first_workshop,
  d.lead_time_deliveries AS lead_time_deliveries,
  bl.backlog AS backlog,
  bl.age_of_backlog AS age_of_backlog,
  can.number_of_cancellations AS number_of_cancellations
FROM
  Bookings b
LEFT JOIN
  Deliveries d ON b.week = d.week AND b.retail_country = d.retail_country
LEFT JOIN
  Backlog bl ON b.week = bl.week AND b.retail_country = bl.retail_country
LEFT JOIN
  Cancellations can ON b.week = can.week AND b.retail_country = can.retail_country
ORDER BY
  b.week, b.retail_country
  
  
  
  
  
  
  
  
  
-- Additional analysys for data understanding

-- car data  
SELECT *
FROM car_data
LIMIT 10;

-- distribution of bookings by country and the amount of cars
SELECT booking_country, COUNT(*) AS total_cars
FROM car_data
GROUP BY booking_country
ORDER BY total_cars DESC;


-- where most cars are being refurbished.
SELECT retail_country, COUNT(*) AS total_bookings
FROM car_data
GROUP BY retail_country
ORDER BY total_bookings DESC;

-- transport data
SELECT *
FROM transport_data
LIMIT 100;

--  how many cars are in each status 
SELECT status, COUNT(*) AS total_cars
FROM transport_data
GROUP BY status
ORDER BY status;

-- check the booking dates to understand the date range, which is till April 2022
SELECT MIN(booking_date) AS min_booking_date, MAX(booking_date) AS max_booking_date
FROM car_data;


-- new columns for car_data table
ALTER TABLE car_data
ADD COLUMN new_booking_date DATE,
ADD COLUMN new_unbooking_date DATE;

-- new columns for  transport_data table
ALTER TABLE transport_data
ADD COLUMN new_order_date DATE,
ADD COLUMN new_delivery_date DATE,
ADD COLUMN new_canceled_date DATE;

-- new columns for  daily_grid table
ALTER TABLE daily_grid
ADD COLUMN new_day DATE;

-- Update new columns in car_data table
UPDATE car_data
SET new_booking_date = CASE WHEN booking_date = '' THEN NULL ELSE booking_date::DATE END,
    new_unbooking_date = CASE WHEN unbooking_date = '' THEN NULL ELSE unbooking_date::DATE END;

-- Update new columns in transport_data table
UPDATE transport_data
SET new_order_date = CASE WHEN order_date = '' THEN NULL ELSE order_date::DATE END,
    new_delivery_date = CASE WHEN delivery_date = '' THEN NULL ELSE delivery_date::DATE END,
    new_canceled_date = CASE WHEN canceled_date = '' THEN NULL ELSE canceled_date::DATE END;

-- Update new column in daily_grid table
UPDATE daily_grid
SET new_day = CASE WHEN day = '' THEN NULL ELSE day::DATE END;

