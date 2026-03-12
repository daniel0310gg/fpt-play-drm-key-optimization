-- ============================================================
-- 04_outlier_detection.sql
-- Statistical Outlier Detection: 2-Sigma & IQR Methods
-- ============================================================
--
-- METHODOLOGY CHOICE:
--   We apply both methods and compare results.
--   When two methods disagree, the DISAGREEMENT is the insight —
--   not an error. Here, 2σ flags high weekends as outliers
--   because it is pulled down by low weekdays. IQR, based on
--   the middle 50% of data, is more robust to this skew.
--
-- KEY INSIGHT: April 4-5 (Easter Weekend, COVID lockdown) was
--   flagged by 2σ only — elevated viewership was expected,
--   not anomalous. Business context resolved the disagreement.
-- ============================================================

USE SCHEMA drm_analysis;

-- -----------------------------------------------
-- Step 1: Calculate statistical parameters
-- -----------------------------------------------
WITH StatParams AS (
    SELECT
        AVG(drm_keys_needed)                            AS mean_val,
        STDDEV(drm_keys_needed)                         AS std_val,
        PERCENTILE_APPROX(drm_keys_needed, 0.25)        AS q1,
        PERCENTILE_APPROX(drm_keys_needed, 0.50)        AS median_val,
        PERCENTILE_APPROX(drm_keys_needed, 0.75)        AS q3
    FROM daily_drm_demand
),

-- -----------------------------------------------
-- Step 2: Derive fence thresholds from parameters
-- -----------------------------------------------
Thresholds AS (
    SELECT
        mean_val,
        std_val,
        q1,
        median_val,
        q3,
        -- 2-Sigma fences
        mean_val + (2 * std_val)            AS sigma2_upper,
        mean_val - (2 * std_val)            AS sigma2_lower,
        -- IQR fences (Tukey method: 1.5 x IQR)
        q3 + 1.5 * (q3 - q1)               AS iqr_upper,
        q1 - 1.5 * (q3 - q1)               AS iqr_lower
    FROM StatParams
),

-- -----------------------------------------------
-- Step 3: Flag each day against both methods
-- -----------------------------------------------
OutlierFlags AS (
    SELECT
        d.date,
        d.day_of_week_name,
        d.drm_keys_needed,
        -- 2-Sigma flags
        CASE WHEN d.drm_keys_needed > t.sigma2_upper THEN 'HIGH'
             WHEN d.drm_keys_needed < t.sigma2_lower THEN 'LOW'
             ELSE 'Normal'
        END AS sigma2_flag,
        -- IQR flags
        CASE WHEN d.drm_keys_needed > t.iqr_upper THEN 'HIGH'
             WHEN d.drm_keys_needed < t.iqr_lower THEN 'LOW'
             ELSE 'Normal'
        END AS iqr_flag,
        -- Rounded thresholds for readability
        ROUND(t.sigma2_upper, 0)            AS sigma2_upper,
        ROUND(t.sigma2_lower, 0)            AS sigma2_lower,
        ROUND(t.iqr_upper, 0)               AS iqr_upper,
        ROUND(t.iqr_lower, 0)               AS iqr_lower,
        ROUND(t.mean_val, 0)                AS mean_val,
        ROUND(t.median_val, 0)              AS median_val
    FROM daily_drm_demand d
    CROSS JOIN Thresholds t
)

-- -----------------------------------------------
-- Step 4: Show flagged days with disagreement analysis
-- -----------------------------------------------
SELECT
    date,
    day_of_week_name,
    drm_keys_needed,
    sigma2_flag,
    iqr_flag,
    -- Highlight method disagreements — these are the most interesting cases
    CASE
        WHEN sigma2_flag != iqr_flag THEN 'METHODS DISAGREE — investigate'
        WHEN sigma2_flag != 'Normal' THEN 'BOTH FLAG — strong outlier'
        ELSE 'Both Normal'
    END AS analysis_note,
    sigma2_upper,
    sigma2_lower,
    iqr_upper,
    iqr_lower
FROM OutlierFlags
WHERE sigma2_flag != 'Normal' OR iqr_flag != 'Normal'
ORDER BY date;

-- -----------------------------------------------
-- Expected output:
-- Apr 04 (Sat)  → 13,932 keys → 2σ: HIGH | IQR: Normal | METHODS DISAGREE
-- Apr 05 (Sun)  → 14,109 keys → 2σ: HIGH | IQR: Normal | METHODS DISAGREE
--
-- Root cause: Easter Weekend during COVID-19 lockdown.
-- Elevated viewership expected — not a true anomaly.
-- The 2σ method was biased because weekday lows pulled the mean down.
-- -----------------------------------------------


-- -----------------------------------------------
-- Step 5: Summary of all outliers for BD report
-- -----------------------------------------------
SELECT
    sigma2_flag,
    iqr_flag,
    COUNT(*) AS day_count,
    ROUND(AVG(drm_keys_needed), 0) AS avg_keys_on_flagged_days
FROM OutlierFlags
WHERE sigma2_flag != 'Normal' OR iqr_flag != 'Normal'
GROUP BY sigma2_flag, iqr_flag
ORDER BY sigma2_flag, iqr_flag;
