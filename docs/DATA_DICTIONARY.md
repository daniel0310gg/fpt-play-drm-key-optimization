# Data Dictionary

## Overview
This project uses six datasets stored in the `drm_analysis` schema on Databricks.
The data spans **April 3 – June 1, 2020** (60 usable days), covering the COVID-19 lockdown period in Vietnam.

---

## Table: `mv_properties_show_vn`
**Description:** Content metadata for all titles on FPT Play.
The `isDRM` flag identifies which content requires a DRM key to view.

| Column | Type | Description |
|---|---|---|
| `id` | BIGINT | Unique content identifier. Used to JOIN with viewing logs. |
| `toptitle` | STRING | Vietnamese title of the content |
| `titleEN` | STRING | English title |
| `release` | DOUBLE | Release year |
| `actors` | STRING | Cast list |
| `directors` | STRING | Director(s) |
| `Producers` | STRING | Producer(s) |
| `PublishCountry` | STRING | Country of origin |
| `Duration` | DOUBLE | Duration in minutes |
| `isDRM` | INT | **Key flag.** `1` = locked content (DRM key required). `0` = free content. |

> **Critical note:** Only ~23% of titles have `isDRM = 1`. All queries filtering for DRM key demand must include `WHERE isDRM = 1`.

---

## Table: `customer_service`
**Description:** Customer subscription records. Links each customer to their active service packages.

| Column | Type | Description |
|---|---|---|
| `CustomerID` | BIGINT | Unique customer identifier. Foreign key to all log tables. |
| `ServiceID` | INT | The service/package the customer subscribed to |
| `Amount` | DOUBLE | Transaction amount |
| `Date` | DATE | Subscription date |

**Relevant ServiceIDs for DRM validation:**

| ServiceID | Service |
|---|---|
| 60 | K+ |
| 89 | Đặc Sắc |
| 148 | Phim Gói variant |
| 149 | Phim Gói variant |
| 150 | Phim Gói variant |
| 154 | Phim Gói variant |

> **Usage:** JOIN this table against `log_get_drm_list` to validate that DRM requests come from customers with an active subscription. Without this JOIN, ghost/test accounts can inflate the count.

---

## Table: `log_get_drm_list`
**Description:** DRM key request log for **Phim Gói (K+ / Đặc Sắc)** content only.

| Column | Type | Description |
|---|---|---|
| `CustomerID` | BIGINT | Customer who requested the DRM key |
| `Date` | STRING | Date of the request (cast to DATE in queries) |
| `Mac` | STRING | MAC address of the requesting device. One key is issued per unique MAC. |

> ⚠️ **Critical assumption to correct:** This table was originally documented as the "master DRM table." In reality, it only covers one content type (Phim Gói). BHD and FIM+ content are tracked in separate log tables. All three sources must be combined for an accurate count.

---

## Table: `log_bhd_movie_id` *(source DB)*
**Description:** Viewing log for BHD film content. Must be filtered to `isDRM = 1` content only.

| Column | Type | Description |
|---|---|---|
| `CustomerID` | BIGINT | Customer who viewed the content |
| `MovieID` | BIGINT | Content ID. JOIN to `mv_properties_show_vn` on `id`. |
| `FType` | STRING | Content type flag |
| `Date` | TIMESTAMP | Viewing timestamp |

---

## Table: `log_fimplus_movie_id` *(source DB)*
**Description:** Viewing log for FIM+ content. Must be filtered to `isDRM = 1` content only.

| Column | Type | Description |
|---|---|---|
| `CustomerID` | BIGINT | Customer who viewed the content |
| `MovieID` | BIGINT | Content ID. JOIN to `mv_properties_show_vn` on `id`. |
| `FType` | STRING | Content type flag |
| `Date` | TIMESTAMP | Viewing timestamp |

---

## Key Metrics & Constants

| Parameter | Value | Source |
|---|---|---|
| Total quota | 380,000 keys | Business requirement |
| Current holding | 334,000 keys | System record |
| Avg daily usage (our dataset) | ~11,164 keys/day | Phase 2 analysis |
| Peak day usage | 14,109 keys (Apr 5, 2020) | Phase 2 analysis |
| Dataset date range | 2020-04-03 to 2020-06-01 | Data validation |
| Unique devices | 40,763 | Phase 1 analysis |
| Unique customers | 39,705 | Phase 1 analysis |
| Devices per customer | 1.03 | Derived |
| DRM content ratio | ~23% of all titles | Phase 1 analysis |
