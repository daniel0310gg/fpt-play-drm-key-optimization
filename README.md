# 🔐 FPT Play — DRM Key Usage Analysis & Budget Optimization

> **A data analytics project to provide data-driven insights for optimizing Digital Rights Management (DRM) key budget allocation on FPT Play, a Vietnamese streaming platform.**

---

## 📋 Table of Contents
- [Executive Summary](#executive-summary)
- [Business Context](#business-context)
- [Dataset Overview](#dataset-overview)
- [Project Architecture](#project-architecture)
- [Methodology](#methodology)
- [Key Findings](#key-findings)
- [Repository Structure](#repository-structure)
- [How to Run](#how-to-run)
- [Tech Stack](#tech-stack)

---

## Executive Summary

FPT Play holds **380,000 DRM keys** (334,000 currently assigned), yet peak daily usage across the April–June 2020 period was only **14,109 keys/day** — a utilization rate of **4.22%**. This project delivers the analytical foundation to right-size that holding, potentially unlocking significant budget savings.

| Metric | Value |
|---|---|
| Total Quota | 380,000 keys |
| Currently Held | 334,000 keys |
| Avg Daily Usage (our dataset) | ~11,164 keys/day |
| Peak Day Ever | 14,109 keys (Apr 5, 2020) |
| Recommended Safe Ceiling | ~16,000 keys (avg + 2σ + 20% buffer) |
| Estimated Excess Holding | ~318,000 keys (~95% unnecessary) |

> ⚠️ **Important caveat:** This analysis covers April–June 2020, a COVID-19 lockdown period representing *peak* viewership. Normal usage would likely be lower, which strengthens the over-provisioning finding.

---

## Business Context

### What is a DRM Key?
A DRM (Digital Rights Management) key is a unique license assigned to a device (identified by its MAC address) that unlocks premium content on FPT Play — including SVOD, TVOD, AVOD, K+, and Special content.

### The Equivalence Principle
> **DRM keys granted per day ≡ Unique daily viewers of locked content**

Because a device must hold a key to watch any locked content, counting distinct daily viewers across all locked content sources gives us the precise daily key demand.

### The Business Problem
- Keys are purchased at cost — holding 334,000 keys represents a significant budget commitment
- But keys operate as a **reusable pool**: only *concurrent users* need keys, not all subscribers
- Current holding (~334k) vastly exceeds observed peak demand (~14k)
- The BD (Business Department) needs data-driven evidence to optimize the quota

### Usage Patterns
- Demand is **cyclical**: decreases Monday–Thursday, peaks Saturday–Sunday
- **Weekend premium: ~+15%** above weekday baseline
- **External events** (lockdowns, public holidays) spike demand temporarily

---

## Dataset Overview

| Table | Records | Description |
|---|---|---|
| `Log_Get_DRM_List` | 663,594 | DRM key requests for Phim Gói (K+/Đặc Sắc) package |
| `MV_PropertiesShowVN` | 28,807 | Content metadata — isDRM flag identifies locked content |
| `CustomerService` | 160,125 | Customer subscription records with ServiceID |
| `Log_BHD_MovieID` | ~millions | Viewing logs for BHD film content |
| `Log_FimPlus_MovieID` | ~millions | Viewing logs for FIM+ content |

**Date Range:** April 3 – June 1, 2020 (60 usable days)

**Critical Discovery:** `Log_Get_DRM_List` captures only one content type (Phim Gói), not all DRM sources. A proper count requires combining all three log sources.

---

## Project Architecture

```
Data Sources
├── Log_BHD_MovieID        ──┐
├── Log_FimPlus_MovieID    ──┤── UNION (deduplicate cross-platform viewers)
└── Log_Get_DRM_List       ──┘
        │
        ▼
MV_PropertiesShowVN        ── Filter: isDRM = 1 (only 23% of content)
        │
        ▼
CustomerService             ── Validate active subscribers (ServiceID filter)
        │
        ▼
COUNT DISTINCT CustomerID per day  ──▶  Daily DRM Key Demand
```

---

## Methodology

### Phase 1 — Data Understanding & Setup
- Validated all six datasets: zero null values, correct date ranges
- Discovered 40,763 unique devices / 39,705 unique customers → **1.03 devices per customer**
- Identified that only **23% of content** in `MV_PropertiesShowVN` requires DRM keys
- Reverse-engineered correct business logic from the original developer's SQL query

### Phase 2 — Descriptive Analytics
Built the complete DRM key calculation combining all three sources:

```
BHD logs   ──┐
              ├── UNION (deduplicate) ──┐
FIM+ logs  ──┘                          ├── UNION ──▶ COUNT DISTINCT per day
                                         │
Phim Gói   ── JOIN CustomerService  ───┘
```

**Results:**
| Metric | Value |
|---|---|
| Average daily keys | 11,164 |
| Minimum | 9,032 |
| Maximum | 14,109 |
| Std Deviation | 1,304 |
| Weekday avg (Mon–Thu) | ~10,600 |
| Weekend avg (Sat–Sun) | ~12,200 |

### Phase 3 — Statistical Modeling & Outlier Detection
Applied both **2-sigma** and **IQR** methods to identify abnormal days.

| Method | Upper Fence | Lower Fence |
|---|---|---|
| 2σ | 13,773 | 8,555 |
| IQR | 15,288 | 6,935 |

**Flagged outliers:** Apr 4–5 (Easter Weekend during COVID-19 lockdown) — elevated but explainable.

**Monthly trend:**
| Month | Avg Keys | Std Dev | Context |
|---|---|---|---|
| April | 11,966 | 982 | Lockdown peak — elevated, stable |
| May | 10,509 | 1,133 | Reopening — declining, more volatile |
| June | ~9,032 | — | Trending toward post-lockdown baseline |

---

## Key Findings

### Finding 1 — Normal Operating Range: 9,000–14,000 keys/day
The current quota of 380,000 is massively oversized for observed demand.

### Finding 2 — Demand is Cyclical (+15% on weekends)
Budget planning must account for weekly and seasonal patterns. Lockdowns spike demand; reopening deflates it.

### Finding 3 — Only 4.22% of Held Keys Are Used on Peak Days
```
Keys currently held    = 334,000
Peak day ever recorded =  14,109
Utilization rate       =   4.22%

Recommended safe ceiling  = avg + 2σ + 20% buffer ≈ 16,000 keys
Estimated excess holding  = 334,000 - 16,000      = 318,000 keys
```

---

## Repository Structure

```
drm-key-optimization/
├── README.md
├── sql/
│   ├── 01_schema_setup.sql          # Databricks schema and table definitions
│   ├── 02_daily_drm_count.sql       # Core DRM key counting query (all sources)
│   ├── 03_descriptive_stats.sql     # Summary statistics per day/week/month
│   ├── 04_outlier_detection.sql     # 2σ and IQR outlier flagging
│   └── 05_monthly_trend.sql         # Monthly aggregation and trend analysis
├── notebooks/
│   └── drm_analysis_databricks.py  # Full Databricks notebook (Python + SQL)
├── docs/
│   ├── DATA_DICTIONARY.md           # Field definitions for all tables
│   ├── BUSINESS_LOGIC.md            # DRM equivalence principle & counting rules
│   └── FINDINGS.md                  # Full analytical findings for BD
└── data/
    └── .gitkeep                     # Upload your CSVs here (not tracked by git)
```

---

## How to Run

### Prerequisites
- Databricks workspace (Community Edition works)
- Python 3.8+ with `pandas`, `matplotlib`, `seaborn`, `statsmodels`

### Setup
```bash
git clone https://github.com/<your-username>/drm-key-optimization.git
cd drm-key-optimization
```

### Step 1 — Create Schema
Run `sql/01_schema_setup.sql` in your Databricks SQL editor to create the `drm_analysis` schema and upload your CSV files.

### Step 2 — Run Core Analysis
Execute the SQL files in order (01 → 05), or run the full notebook `notebooks/drm_analysis_databricks.py`.

### Step 3 — Review Findings
See `docs/FINDINGS.md` for the complete analytical report with business recommendations.

---

## Tech Stack

| Tool | Purpose |
|---|---|
| **Databricks** | Primary analysis environment (SQL + Python notebooks) |
| **Apache Spark SQL** | Distributed query execution |
| **Python / pandas** | Data wrangling and statistical modeling |
| **matplotlib / seaborn** | Visualization |
| **statsmodels (ARIMA)** | Time series forecasting |
| **sklearn** | Linear regression modeling |

---

## Author

**DanielBe** — Data Analyst, FPT Play  
*Analysis period: April–June 2020*
