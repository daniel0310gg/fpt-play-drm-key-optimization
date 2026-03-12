-- ============================================================
-- 03_descriptive_stats.sql
-- Descriptive Analytics: Summary Statistics
-- ============================================================
-- Requires: output from 02_daily_drm_count.sql
-- Run 02 first and store results as a temp view or table.
-- ============================================================

USE SCHEMA drm_analysis;

-- Save daily counts as a reusable view
CREATE OR REPLACE TEMP VIEW daily_drm_demand AS
-- [Paste full CTE from 02_daily_drm_count.sql here,
--  or reference a saved table if you materialized it]
SELECT * FROM drm_analysis.daily_key_demand_results;


-- ============================================================
-- 1. OVERALL SUMMARY STATISTICS
-- ============================================================
SELECT
    COUNT(*)                                    AS total_days,
    ROUND(AVG(drm_keys_needed), 0)              AS mean_daily_keys,
    ROUND(STDDEV(drm_keys_needed), 0)           AS std_dev,
    MIN(drm_keys_needed)                        AS min_keys,
    MAX(drm_keys_needed)                        AS max_keys,
    ROUND(PERCENTILE_APPROX(drm_keys_needed, 0.25), 0) AS q1,
    ROUND(PERCENTILE_APPROX(drm_keys_needed, 0.50), 0) AS median,
    ROUND(PERCENTILE_APPROX(drm_keys_needed, 0.75), 0) AS q3,
    -- Utilization rate against current holding
    ROUND(MAX(drm_keys_needed) * 100.0 / 334000, 2)   AS peak_utilization_pct,
    -- Safe ceiling: mean + 2 std dev + 20% safety buffer
    ROUND((AVG(drm_keys_needed) + 2 * STDDEV(drm_keys_needed)) * 1.2, 0) AS recommended_safe_ceiling
FROM daily_drm_demand;

-- Expected results:
-- mean     ~11,164   std_dev  ~1,304
-- min       ~9,032   max      ~14,109
-- peak utilization vs 334k holding: ~4.22%
-- recommended ceiling: ~16,000


-- ============================================================
-- 2. DAY-OF-WEEK PATTERN ANALYSIS
-- ============================================================
SELECT
    day_of_week_name,
    day_of_week_num,
    COUNT(*)                                    AS sample_days,
    ROUND(AVG(drm_keys_needed), 0)              AS avg_keys,
    ROUND(STDDEV(drm_keys_needed), 0)           AS std_dev,
    MIN(drm_keys_needed)                        AS min_keys,
    MAX(drm_keys_needed)                        AS max_keys
FROM daily_drm_demand
GROUP BY day_of_week_name, day_of_week_num
ORDER BY day_of_week_num;

-- Expected pattern:
-- Mon–Thu: ~10,600 keys (weekday trough)
-- Fri:     transition day
-- Sat–Sun: ~12,200 keys (+15% weekend premium)


-- ============================================================
-- 3. MONTHLY TREND ANALYSIS
-- ============================================================
SELECT
    month_name,
    month_num,
    COUNT(*)                                    AS days_in_month,
    ROUND(AVG(drm_keys_needed), 0)              AS avg_keys,
    ROUND(STDDEV(drm_keys_needed), 0)           AS std_dev,
    MIN(drm_keys_needed)                        AS min_keys,
    MAX(drm_keys_needed)                        AS max_keys,
    -- Month-over-month change (requires LAG)
    ROUND(
        (AVG(drm_keys_needed) - LAG(AVG(drm_keys_needed)) OVER (ORDER BY month_num))
        * 100.0
        / NULLIF(LAG(AVG(drm_keys_needed)) OVER (ORDER BY month_num), 0),
    1) AS mom_change_pct
FROM daily_drm_demand
GROUP BY month_name, month_num
ORDER BY month_num;

-- Expected:
-- April: avg ~11,966 | COVID lockdown peak, low volatility
-- May:   avg ~10,509 | -12% — lockdown lifted April 23
-- June:  avg ~9,032  | trending toward post-lockdown baseline


-- ============================================================
-- 4. WEEKEND vs WEEKDAY SPLIT
-- ============================================================
SELECT
    CASE
        WHEN day_of_week_num IN (1, 7) THEN 'Weekend'
        ELSE 'Weekday'
    END AS day_type,
    COUNT(*)                                    AS sample_days,
    ROUND(AVG(drm_keys_needed), 0)              AS avg_keys,
    ROUND(STDDEV(drm_keys_needed), 0)           AS std_dev
FROM daily_drm_demand
GROUP BY
    CASE WHEN day_of_week_num IN (1, 7) THEN 'Weekend' ELSE 'Weekday' END;

-- Expected weekend premium: ~+15% above weekday baseline
