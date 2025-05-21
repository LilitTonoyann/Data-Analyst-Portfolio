
-- Project: Vehicle Service Center KPI Reporting
-- Description:
-- This SQL script analyzes vehicle service data across multiple service centers.
-- It classifies services into categories, creates weekly and monthly metrics,
-- and clusters services by estimated time and cost for business insights.

-- Step 1: Define time boundaries
WITH limits AS (
    SELECT
        DATE_TRUNC('week', CURRENT_DATE - INTERVAL '5 days') AS weekly_limit,
        DATE_TRUNC('month', CURRENT_DATE - INTERVAL '5 days') AS monthly_limit
),

-- Step 2: Generate weekly calendar view
calendar_grid AS (
    SELECT DISTINCT
        TO_CHAR(date_day, 'YYYY_IW') AS week,
        TO_CHAR(date_day, 'YYYY_MM') AS month
    FROM calendar_dates
    CROSS JOIN limits
    WHERE date_day BETWEEN limits.weekly_limit AND CURRENT_DATE
),

-- Step 3: Prepare base service data
service_data AS (
    SELECT
        vehicle_id,
        service_date,
        service_center,
        region,
        service_name,
        service_type,
        cost_eur,
        estimated_time,
        TO_CHAR(service_date, 'YYYY_IW') AS week,
        TO_CHAR(service_date, 'YYYY_MM') AS month
    FROM vehicle_repairs
    WHERE service_date >= (SELECT monthly_limit FROM limits)
),

-- Step 4: Classify services
classified_services AS (
    SELECT *,
        CASE
            WHEN service_type IN ('TYPE_A1', 'TYPE_A2') THEN 'category_a'
            WHEN service_type IN ('TYPE_B1', 'TYPE_B2') THEN 'category_b'
            ELSE 'uncategorized'
        END AS category
    FROM service_data
),

-- Step 5: Cluster by time and cost
clustered_services AS (
    SELECT
        *,
        CASE
            WHEN estimated_time <= 120 THEN 'time_0_2h'
            WHEN estimated_time <= 240 THEN 'time_2_4h'
            WHEN estimated_time <= 360 THEN 'time_4_6h'
            ELSE 'time_6h_plus'
        END AS time_cluster,
        CASE
            WHEN cost_eur <= 50 THEN 'cost_0_50'
            WHEN cost_eur <= 150 THEN 'cost_50_150'
            WHEN cost_eur <= 300 THEN 'cost_150_300'
            ELSE 'cost_300_plus'
        END AS cost_cluster
    FROM classified_services
),

-- Step 6: Weekly aggregation
weekly_summary AS (
    SELECT
        week AS period,
        'week' AS period_type,
        region,
        service_center,
        category,
        COUNT(DISTINCT vehicle_id) AS vehicles_serviced,
        SUM(cost_eur) AS total_cost,
        SUM(estimated_time) AS total_time,
        COUNT(*) FILTER (WHERE time_cluster = 'time_0_2h') AS time_0_2h,
        COUNT(*) FILTER (WHERE cost_cluster = 'cost_0_50') AS cost_0_50
    FROM clustered_services
    GROUP BY 1, 2, 3, 4, 5
),

-- Step 7: Monthly aggregation
monthly_summary AS (
    SELECT
        month AS period,
        'month' AS period_type,
        region,
        service_center,
        category,
        COUNT(DISTINCT vehicle_id) AS vehicles_serviced,
        SUM(cost_eur) AS total_cost,
        SUM(estimated_time) AS total_time,
        COUNT(*) FILTER (WHERE time_cluster = 'time_0_2h') AS time_0_2h,
        COUNT(*) FILTER (WHERE cost_cluster = 'cost_0_50') AS cost_0_50
    FROM clustered_services
    GROUP BY 1, 2, 3, 4, 5
)

-- Final Output
SELECT CURRENT_DATE AS report_generated_at, * FROM (
    SELECT * FROM weekly_summary
    UNION ALL
    SELECT * FROM monthly_summary
) final_results;
