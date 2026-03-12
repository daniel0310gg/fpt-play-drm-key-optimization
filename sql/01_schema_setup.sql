-- ============================================================
-- 01_schema_setup.sql
-- FPT Play DRM Key Analysis — Databricks Schema & Table Setup
-- ============================================================
-- Run this first. Upload your CSVs to DBFS before running.
-- ============================================================

CREATE SCHEMA IF NOT EXISTS drm_analysis
COMMENT 'FPT Play DRM key usage analysis — April to June 2020';

USE SCHEMA drm_analysis;

-- Content metadata: isDRM=1 means the content requires a DRM key
CREATE TABLE IF NOT EXISTS drm_analysis.mv_properties_show_vn (
    id              BIGINT,
    toptitle        STRING,
    titleEN         STRING,
    release         DOUBLE,
    actors          STRING,
    directors       STRING,
    Producers       STRING,
    PublishCountry  STRING,
    Duration        DOUBLE,
    isDRM           INT   -- 1 = locked content (only ~23% of total)
);

-- Customer subscription records: links CustomerID → ServiceID
CREATE TABLE IF NOT EXISTS drm_analysis.customer_service (
    CustomerID  BIGINT,
    ServiceID   INT,
    Amount      DOUBLE,
    Date        DATE
);

-- DRM key request log — Phim Goi (K+ / Dac Sac) ONLY
-- NOTE: This is NOT the master DRM table.
-- Must be combined with Log_BHD and Log_FimPlus for full picture.
CREATE TABLE IF NOT EXISTS drm_analysis.log_get_drm_list (
    CustomerID  BIGINT,
    Date        STRING,  -- cast to DATE in queries
    Mac         STRING   -- device MAC address (1 key per MAC)
);

-- -----------------------------------------------
-- Post-upload validation queries
-- -----------------------------------------------
SELECT 'mv_properties_show_vn' AS tbl, COUNT(*) AS rows FROM drm_analysis.mv_properties_show_vn
UNION ALL
SELECT 'customer_service', COUNT(*) FROM drm_analysis.customer_service
UNION ALL
SELECT 'log_get_drm_list', COUNT(*) FROM drm_analysis.log_get_drm_list;
-- Expected: 28,807 | 160,125 | 663,594

-- DRM content ratio check
SELECT
    isDRM,
    COUNT(*) AS content_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS pct
FROM drm_analysis.mv_properties_show_vn
GROUP BY isDRM;
-- Expected: isDRM=0 → ~77%, isDRM=1 → ~23%

-- Date range & device uniqueness check
SELECT
    MIN(CAST(Date AS DATE)) AS earliest,
    MAX(CAST(Date AS DATE)) AS latest,
    COUNT(DISTINCT CAST(Date AS DATE)) AS distinct_days,
    COUNT(DISTINCT CustomerID)         AS unique_customers,
    COUNT(DISTINCT Mac)                AS unique_devices
FROM drm_analysis.log_get_drm_list;
-- Expected: 2020-04-03 | 2020-06-01 | ~60 days | 39,705 | 40,763
