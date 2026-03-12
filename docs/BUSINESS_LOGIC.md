# Business Logic & Analytical Rules

## The DRM Key Model

### What is a DRM Key?
A DRM (Digital Rights Management) key is a software license issued to a device (identified by its MAC address) that grants access to premium locked content on FPT Play. Without an active DRM key, the device cannot stream SVOD, TVOD, AVOD, K+, or Đặc Sắc content.

### Key-per-Device Architecture
- Each **unique MAC address** holds exactly **one DRM key**
- Keys are **reusable** — a key does not expire after one viewing session
- The pool is **shared** — only concurrent users need keys, not all subscribers
- This is why 334,000 keys for millions of subscribers is (in theory) economically rational — only a fraction watch locked content on any given day

---

## The Equivalence Principle

> **DRM keys granted per day ≡ Unique daily viewers of locked content**

This is the foundational counting logic. If a customer watches any locked content on day X using their device, that device must hold a DRM key. Therefore:

```
Keys needed on day X = COUNT DISTINCT (CustomerID who watched locked content on day X)
```

We count by `CustomerID` rather than `Mac` because:
1. One customer may have multiple devices (avg: 1.03 devices per customer)
2. The business goal is understanding *customer* demand, not device count

---

## Three DRM Content Sources

Not all locked content is tracked in the same log table. Three separate platforms each generate DRM key demand:

| Source | Log Table | Notes |
|---|---|---|
| BHD Films | `Log_BHD_MovieID` | Filter to `isDRM = 1` via JOIN with `MV_PropertiesShowVN` |
| FIM+ Content | `Log_FimPlus_MovieID` | Filter to `isDRM = 1` via JOIN with `MV_PropertiesShowVN` |
| Phim Gói (K+/Đặc Sắc) | `Log_Get_DRM_List` | All records are DRM by definition; JOIN with `CustomerService` to validate subscriber status |

---

## Why UNION, Not JOIN?

A customer may watch BHD content AND Phim Gói content on the same day. They still only need **one DRM key**. Using a JOIN between sources would create duplicate rows for that customer. Using `UNION` (not `UNION ALL`) deduplicates at the `CustomerID + date` level before counting:

```sql
-- Correct: UNION deduplicates cross-platform viewers
SELECT CustomerID, date FROM ViewBHD
UNION
SELECT CustomerID, date FROM ViewFimPlus
UNION
SELECT CustomerID, date FROM ViewPhimGoi

-- Then: COUNT DISTINCT CustomerID per date
```

---

## CustomerService Validation Rule

`Log_Get_DRM_List` records who *requested* a key, but not all requestors are valid paying subscribers. Ghost accounts or test accounts with `CustomerID != 0` can appear. The validation JOIN with `CustomerService`:

```sql
WHERE CS.ServiceID IN (60, 89, 148, 149, 150, 154)
```

ensures we only count customers who hold an active subscription to a relevant package.

**Practical adaptation:** When daily active subscription status is unavailable, we use customers who have *ever* subscribed to the relevant ServiceIDs. This slightly overestimates demand but maintains methodological consistency.

---

## Why Our Numbers Differ from Documentation

The original business documentation cited ~19,171 keys/day as the mean. Our analysis of the April–June 2020 dataset yields ~11,164 keys/day. **Both can be correct simultaneously** because:

1. The documented figure likely draws from a broader dataset spanning more months with different viewership conditions
2. Our dataset is a 60-day window during a specific period (COVID lockdown)
3. Our weekly pattern (Mon–Thu trough, Sat–Sun peak, +15% weekend premium) perfectly matches the documented pattern — confirming methodology is correct even when absolute numbers differ

---

## Statistical Methodology Notes

### 2-Sigma Method
- Upper fence: `mean + 2 × std_dev`
- Lower fence: `mean - 2 × std_dev`
- **Weakness:** The mean is pulled down by low-demand weekdays, making high-demand weekends appear anomalous when they are not

### IQR Method (Tukey)
- Upper fence: `Q3 + 1.5 × IQR`
- Lower fence: `Q1 - 1.5 × IQR`
- **Strength:** Based on the middle 50% of data — more robust to systematic weekday/weekend patterns

### Rule of Interpretation
> When two methods disagree, the disagreement itself is the insight. Do not just pick the answer you prefer — investigate the root cause.

In this analysis: April 4–5 (Easter Weekend, COVID lockdown) was flagged by 2σ but not IQR. Business context confirmed elevated viewership was expected, not anomalous.
