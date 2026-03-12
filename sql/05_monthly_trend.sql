-- ============================================================
-- 05_monthly_trend.sql
-- Monthly Trend & Business Insight Summary
-- ============================================================
-- Interprets the April-to-June decline in context of
-- Vietnam's COVID-19 lockdown and reopening (April 23, 2020)
-- ============================================================

USE SCHEMA drm_analysis;

-- -----------------------------------------------
-- 1. Weekly rolling average — smooths day-of-week noise
-- -----------------------------------------------
SELECT
    date,
    drm_keys_needed,
    day_of_week_name,
    ROUND(
        AVG(drm_keys_needed) OVER (
            ORDER BY date
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ), 0
    ) AS rolling_7day_avg,
    ROUND(
        AVG(drm_keys_needed) OVER (
            ORDER BY date
            ROWS BETWEEN 13 PRECEDING AND CURRENT ROW
        ), 0
    ) AS rolling_14day_avg
FROM daily_drm_demand
ORDER BY date;


-- -----------------------------------------------
-- 2. Pre/Post lockdown comparison
-- Vietnam lifted restrictions approximately April 23, 2020
-- -----------------------------------------------
SELECT
    CASE
        WHEN date < '2020-04-23' THEN 'Pre-Reopening (Lockdown)'
        ELSE 'Post-Reopening'
    END AS period,
    COUNT(*)                                    AS days,
    ROUND(AVG(drm_keys_needed), 0)              AS avg_keys,
    ROUND(STDDEV(drm_keys_needed), 0)           AS std_dev,
    MIN(drm_keys_needed)                        AS min_keys,
    MAX(drm_keys_needed)                        AS max_keys
FROM daily_drm_demand
GROUP BY
    CASE WHEN date < '2020-04-23' THEN 'Pre-Reopening (Lockdown)' ELSE 'Post-Reopening' END;

-- Expected: Post-reopening avg significantly lower than lockdown avg
-- This proves demand is contextual — budget planning must account for this


-- -----------------------------------------------
-- 3. Budget optimization summary for BD
-- -----------------------------------------------
WITH Stats AS (
    SELECT
        AVG(drm_keys_needed)        AS mean_val,
        STDDEV(drm_keys_needed)     AS std_val,
        MAX(drm_keys_needed)        AS peak_val
    FROM daily_drm_demand
)
SELECT
    ROUND(mean_val, 0)                                      AS avg_daily_demand,
    ROUND(std_val, 0)                                       AS std_deviation,
    ROUND(peak_val, 0)                                      AS peak_day_ever,
    334000                                                  AS keys_currently_held,
    380000                                                  AS total_quota,
    -- Utilization
    ROUND(peak_val * 100.0 / 334000, 2)                     AS peak_utilization_pct,
    -- Safe ceiling: avg + 2 std dev + 20% buffer
    ROUND((mean_val + 2 * std_val) * 1.2, 0)               AS recommended_ceiling,
    -- Excess holding
    334000 - ROUND((mean_val + 2 * std_val) * 1.2, 0)      AS estimated_excess_keys,
    -- Excess as percentage
    ROUND(
        (334000 - (mean_val + 2 * std_val) * 1.2) * 100.0 / 334000,
    1)                                                      AS excess_pct
FROM Stats;

-- Expected output:
-- avg_daily_demand:      11,164
-- std_deviation:          1,304
-- peak_day_ever:         14,109
-- keys_currently_held:  334,000
-- peak_utilization_pct:   4.22%
-- recommended_ceiling:  ~16,000
-- estimated_excess_keys: ~318,000
-- excess_pct:            ~95.2%
