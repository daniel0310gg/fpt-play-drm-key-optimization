# Analytical Findings & Business Recommendations

**Project:** FPT Play DRM Key Budget Optimization  
**Analyst:** DanielBe  
**Dataset Period:** April 3 – June 1, 2020 (60 days)  
**Prepared for:** Business Department (BD)

---

> ⚠️ **Important Caveat — Read First**
> This analysis covers April–June 2020, which coincides with Vietnam's COVID-19 national lockdown period. Viewership during lockdowns is at its seasonal *peak* — people staying home watch significantly more streaming content than during normal periods. This means our figures represent a **high-demand scenario**, which actually strengthens the over-provisioning finding: if demand is this low even during peak viewership, normal usage would be even lower.

---

## Finding 1 — Normal Daily Key Demand: 9,000 – 14,000 Keys

### Evidence
| Metric | Value |
|---|---|
| Average daily demand | ~11,164 keys/day |
| Standard deviation | ~1,304 keys (~±12%) |
| Minimum recorded | ~9,032 keys/day |
| Maximum recorded | ~14,109 keys/day (Apr 5, 2020) |

### Business Implication
The current quota of **380,000 keys** is designed to serve 380,000 simultaneous viewers. Reality shows **fewer than 15,000 concurrent viewers** ever need a key on any single day during this period.

---

## Finding 2 — Demand is Cyclical: +15% Weekend Premium

### Evidence
| Day Type | Average Keys | Notes |
|---|---|---|
| Monday – Thursday | ~10,600 | Weekday trough |
| Saturday – Sunday | ~12,200 | Weekend peak |
| Weekend premium | **+15%** | Above weekday baseline |

### Monthly Trend (COVID Context)
| Month | Avg Keys/Day | Month-over-Month | Interpretation |
|---|---|---|---|
| April 2020 | ~11,966 | — | Lockdown peak — elevated, stable |
| May 2020 | ~10,509 | **-12%** | Reopening (Apr 23) — demand falling |
| June 2020 | ~9,032 | Declining | Post-lockdown baseline |

The -12% drop from April to May directly maps to Vietnam lifting lockdown restrictions on April 23, 2020.

### Business Implication
Budget planning cannot use a single flat number. It must account for:
- Weekly cycles (weekday trough → weekend peak)
- Seasonal events (major holidays, sports tournaments)
- External shocks (lockdowns, which spike demand unusually high)

---

## Finding 3 — Current Holding Utilizes Only 4.22% of Capacity

### Evidence
```
Keys currently held:       334,000
Peak day ever recorded:     14,109   (Apr 5, 2020)
Peak utilization rate:       4.22%   (14,109 / 334,000)

Mean + 2σ (99.5% confidence):  ~13,772
+ 20% safety buffer:           ~16,527
→ Recommended safe ceiling:    ~16,000 keys

Estimated excess holding:    318,000 keys  (~95% of current holding)
```

### Safe Ceiling Calculation
The recommended ceiling of ~16,000 keys provides:
- **Statistical coverage:** Accounts for 99.5% of all observed days (mean + 2 standard deviations)
- **Safety buffer:** An additional 20% above the statistical maximum
- **Headroom for events:** The buffer absorbs spikes like Easter Weekend and the start of lockdown

### Business Implication
At the data-observed usage rates, FPT Play could reduce its DRM key holding from 334,000 to approximately 16,000–20,000 keys while maintaining full service reliability with a comfortable safety margin. The **~318,000 excess keys represent a significant cost reduction opportunity**.

---

## Outlier Analysis

### Flagged Days
| Date | Day | Keys | 2σ Flag | IQR Flag | Root Cause |
|---|---|---|---|---|---|
| Apr 4, 2020 | Saturday | 13,932 | 🔴 HIGH | ✅ Normal | Easter Weekend + COVID lockdown |
| Apr 5, 2020 | Sunday | 14,109 | 🔴 HIGH | ✅ Normal | Easter Weekend + COVID lockdown (peak) |

### Key Methodological Insight
The two methods disagreed on these two days. This was not a failure — it was the analysis telling us something:
- **2σ** flagged them because the mean was pulled down by low-usage weekdays
- **IQR** correctly identified them as within the normal range for the middle 50% of the dataset

**Conclusion:** These were not true anomalies. Easter Weekend during a national lockdown predictably produces higher viewership. Business context resolved the statistical disagreement.

---

## Summary for BD Decision Making

| # | Finding | Recommended Action |
|---|---|---|
| 1 | Normal demand range: 9,000–14,000 keys/day | Current quota of 380k is massively oversized — initiate right-sizing review |
| 2 | Demand peaks weekends (+15%) and during lockdowns | Model seasonality into future budget planning cycles |
| 3 | Peak utilization: 4.22% — 95% of held keys are unused | Reduce holding to ~16,000–20,000 keys with a phased drawdown plan |

---

## Recommended Next Steps

1. **Confirm with larger dataset** — Replicate this analysis on 12+ months of data to capture a full seasonal cycle including major sporting events (World Cup, V.League, etc.)
2. **Model subscriber growth** — Apply linear regression between active contracts and daily key demand to project future needs as the subscriber base grows
3. **Phased reduction plan** — Rather than a single cut, propose a stepped drawdown: 334k → 80k → 40k → 20k, monitoring utilization at each step
4. **Build a live dashboard** — Automate the daily DRM key count query to give BD real-time visibility into utilization vs. holding

---

*Full methodology documented in `docs/BUSINESS_LOGIC.md`*  
*SQL queries in `sql/` directory*  
*Databricks notebook in `notebooks/drm_analysis_databricks.py`*
