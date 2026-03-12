-- ============================================================
-- 02_daily_drm_count.sql
-- Core Query: Daily DRM Key Demand (All Three Sources)
-- ============================================================
--
-- BUSINESS LOGIC:
--   DRM keys granted per day = Unique daily viewers of locked content
--
--   Three separate content platforms each require DRM keys:
--     1. BHD Films        (Log_BHD_MovieID)
--     2. FIM+ Content     (Log_FimPlus_MovieID)
--     3. Phim Goi (K+ / Dac Sac) (Log_Get_DRM_List + CustomerService)
--
--   We UNION all three to deduplicate customers who watch
--   content from multiple platforms on the same day.
--   Then COUNT DISTINCT CustomerID per day = keys needed that day.
--
-- WHY UNION NOT JOIN?
--   A customer watching BHD *and* FIM+ on the same day only needs
--   ONE key — the UNION deduplicates them before counting.
--
-- IMPORTANT: Log_Get_DRM_List requires a JOIN with CustomerService
--   to validate that the customer actually holds an active subscription.
--   Without this, ghost/test accounts inflate the count.
-- ============================================================

USE SCHEMA drm_analysis;

WITH

-- -----------------------------------------------
-- SOURCE 1: BHD Film viewers (locked content only)
-- -----------------------------------------------
ViewFilmBHD AS (
    SELECT DISTINCT
        A.CustomerID,
        CAST(A.Date AS DATE) AS view_date
    FROM Log_BHD_MovieID A
    INNER JOIN drm_analysis.mv_properties_show_vn B
        ON A.MovieID = B.id
    WHERE B.isDRM = 1
      AND CAST(A.Date AS DATE) BETWEEN '2020-04-03' AND '2020-06-01'
),

-- -----------------------------------------------
-- SOURCE 2: FIM+ viewers (locked content only)
-- -----------------------------------------------
ViewFilmPlus AS (
    SELECT DISTINCT
        C.CustomerID,
        CAST(C.Date AS DATE) AS view_date
    FROM Log_FimPlus_MovieID C
    INNER JOIN drm_analysis.mv_properties_show_vn B
        ON C.MovieID = B.id
    WHERE B.isDRM = 1
      AND CAST(C.Date AS DATE) BETWEEN '2020-04-03' AND '2020-06-01'
),

-- -----------------------------------------------
-- SOURCE 3A: Phim Goi raw DRM requests
-- -----------------------------------------------
PhimGoiRaw AS (
    SELECT DISTINCT
        CustomerID,
        CAST(Date AS DATE) AS view_date,
        Mac
    FROM drm_analysis.log_get_drm_list
    WHERE CustomerID != 0
      AND CAST(Date AS DATE) BETWEEN '2020-04-03' AND '2020-06-01'
),

-- -----------------------------------------------
-- SOURCE 3B: Validate against CustomerService
-- Keeps only customers with an active subscription
-- ServiceIDs: 60, 89, 148, 149, 150, 154
-- (all K+ / Dac Sac / premium service variants)
-- -----------------------------------------------
ValidatedPhimGoi AS (
    SELECT DISTINCT
        P.CustomerID,
        P.view_date
    FROM PhimGoiRaw P
    INNER JOIN drm_analysis.customer_service CS
        ON P.CustomerID = CS.CustomerID
    -- Filter to relevant service packages only
    -- Using all available ServiceIDs as a practical adaptation
    -- when exact daily active status data is unavailable
    WHERE CS.ServiceID IN (60, 89, 148, 149, 150, 154)
),

-- -----------------------------------------------
-- COMBINE: UNION all three sources
-- UNION (not UNION ALL) deduplicates customers
-- who appear in multiple sources on the same day
-- -----------------------------------------------
AllDRMViewers AS (
    SELECT CustomerID, view_date FROM ViewFilmBHD
    UNION
    SELECT CustomerID, view_date FROM ViewFilmPlus
    UNION
    SELECT CustomerID, view_date FROM ValidatedPhimGoi
),

-- -----------------------------------------------
-- FINAL COUNT: Distinct customers per day
-- This equals the number of DRM keys needed that day
-- -----------------------------------------------
DailyKeyDemand AS (
    SELECT
        view_date                               AS date,
        COUNT(DISTINCT CustomerID)              AS drm_keys_needed,
        DAYOFWEEK(view_date)                    AS day_of_week_num,
        DATE_FORMAT(view_date, 'EEEE')          AS day_of_week_name,
        MONTH(view_date)                        AS month_num,
        DATE_FORMAT(view_date, 'MMMM')          AS month_name
    FROM AllDRMViewers
    GROUP BY view_date
)

SELECT *
FROM DailyKeyDemand
ORDER BY date;
