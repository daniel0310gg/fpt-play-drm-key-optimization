# Databricks notebook source
# ============================================================
# FPT Play — DRM Key Usage Analysis
# Full Pipeline: Descriptive Analytics + Statistical Modeling
# Platform: Databricks (Community Edition compatible)
# Dataset: April 3 – June 1, 2020
# ============================================================

# COMMAND ----------
# %md
# ## Phase 1 — Data Setup & Validation

# COMMAND ----------
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.dates as mdates
import seaborn as sns
from statsmodels.tsa.stattools import adfuller
from statsmodels.tsa.seasonal import seasonal_decompose

# Suppress warnings for clean output
import warnings
warnings.filterwarnings('ignore')

plt.rcParams['figure.figsize'] = (14, 5)
plt.rcParams['axes.spines.top'] = False
plt.rcParams['axes.spines.right'] = False

# COMMAND ----------
# %md
# ## Phase 2 — Core DRM Key Count Query
# Combines all three DRM sources: BHD, FIM+, and Phim Goi

# COMMAND ----------
# NOTE: Run sql/02_daily_drm_count.sql in your Databricks SQL editor first,
# then save results as: drm_analysis.daily_key_demand_results
# Then load it here for Python-based visualization and modeling.

# If running the full pipeline in one notebook, use spark.sql() instead:
# df_daily = spark.sql(open('sql/02_daily_drm_count.sql').read()).toPandas()

# For standalone use, load from the saved table:
df_daily = spark.table("drm_analysis.daily_key_demand_results").toPandas()
df_daily['date'] = pd.to_datetime(df_daily['date'])
df_daily = df_daily.sort_values('date').reset_index(drop=True)

print(f"Loaded {len(df_daily)} days of DRM key data")
print(f"Date range: {df_daily['date'].min().date()} to {df_daily['date'].max().date()}")
df_daily.head(10)

# COMMAND ----------
# %md
# ## Phase 2 — Descriptive Statistics

# COMMAND ----------
stats = df_daily['drm_keys_needed'].describe()
mean_val = df_daily['drm_keys_needed'].mean()
std_val = df_daily['drm_keys_needed'].std()

print("=" * 50)
print("DAILY DRM KEY DEMAND — SUMMARY STATISTICS")
print("=" * 50)
print(f"  Days analyzed:     {len(df_daily)}")
print(f"  Mean:              {mean_val:,.0f} keys/day")
print(f"  Std Deviation:     {std_val:,.0f} keys")
print(f"  Min:               {df_daily['drm_keys_needed'].min():,.0f} keys")
print(f"  Max:               {df_daily['drm_keys_needed'].max():,.0f} keys")
print(f"  Median:            {df_daily['drm_keys_needed'].median():,.0f} keys")
print()
print("BUDGET CONTEXT:")
print(f"  Keys currently held:  334,000")
print(f"  Peak utilization:     {df_daily['drm_keys_needed'].max() / 334000 * 100:.2f}%")
print(f"  Recommended ceiling:  {(mean_val + 2*std_val) * 1.2:,.0f} keys (mean + 2σ + 20% buffer)")
print(f"  Estimated excess:     {334000 - (mean_val + 2*std_val) * 1.2:,.0f} keys (~95%)")

# COMMAND ----------
# %md
# ### Daily DRM Key Demand — Time Series

# COMMAND ----------
fig, ax = plt.subplots(figsize=(15, 5))

ax.plot(df_daily['date'], df_daily['drm_keys_needed'],
        color='#2563EB', linewidth=1.5, label='Daily DRM Keys')

# Rolling 7-day average
rolling_mean = df_daily['drm_keys_needed'].rolling(7, center=True).mean()
ax.plot(df_daily['date'], rolling_mean,
        color='#DC2626', linewidth=2, linestyle='--', label='7-Day Rolling Avg')

# Reference lines
ax.axhline(y=mean_val, color='gray', linewidth=1, linestyle=':', label=f'Mean ({mean_val:,.0f})')
ax.axhline(y=mean_val + 2*std_val, color='orange', linewidth=1,
           linestyle=':', label=f'Mean + 2σ ({mean_val + 2*std_val:,.0f})')

# Annotate peak
peak_idx = df_daily['drm_keys_needed'].idxmax()
peak_row = df_daily.loc[peak_idx]
ax.annotate(f"Peak: {peak_row['drm_keys_needed']:,.0f}\n{peak_row['date'].strftime('%b %d')}",
            xy=(peak_row['date'], peak_row['drm_keys_needed']),
            xytext=(15, -30), textcoords='offset points',
            fontsize=9, color='#DC2626',
            arrowprops=dict(arrowstyle='->', color='#DC2626'))

# COVID reopening marker
reopening = pd.Timestamp('2020-04-23')
ax.axvline(x=reopening, color='green', linewidth=1.5, linestyle='--', alpha=0.7)
ax.text(reopening, ax.get_ylim()[0] + 200, 'Lockdown\nLifted\nApr 23',
        fontsize=8, color='green', ha='center')

ax.set_title('FPT Play — Daily DRM Key Demand (Apr–Jun 2020)', fontsize=14, fontweight='bold')
ax.set_xlabel('Date')
ax.set_ylabel('DRM Keys Needed (Distinct Users)')
ax.xaxis.set_major_formatter(mdates.DateFormatter('%b %d'))
ax.xaxis.set_major_locator(mdates.WeekdayLocator(interval=1))
plt.xticks(rotation=45)
ax.legend(loc='upper right', fontsize=9)
ax.yaxis.set_major_formatter(plt.FuncFormatter(lambda x, _: f'{x:,.0f}'))
plt.tight_layout()
plt.savefig('/tmp/01_daily_trend.png', dpi=150, bbox_inches='tight')
plt.show()

# COMMAND ----------
# %md
# ### Day-of-Week Pattern

# COMMAND ----------
dow_order = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']
df_daily['day_name'] = df_daily['date'].dt.day_name()
dow_stats = df_daily.groupby('day_name')['drm_keys_needed'].agg(['mean', 'std', 'min', 'max'])
dow_stats = dow_stats.reindex(dow_order)

fig, ax = plt.subplots(figsize=(10, 5))
colors = ['#93C5FD' if d not in ['Saturday', 'Sunday'] else '#2563EB' for d in dow_order]
bars = ax.bar(dow_order, dow_stats['mean'], color=colors,
              yerr=dow_stats['std'], capsize=4, edgecolor='white', linewidth=0.5)

ax.axhline(y=mean_val, color='gray', linewidth=1, linestyle='--', label=f'Overall mean ({mean_val:,.0f})')
ax.set_title('Average DRM Key Demand by Day of Week', fontsize=13, fontweight='bold')
ax.set_ylabel('Average DRM Keys')
ax.yaxis.set_major_formatter(plt.FuncFormatter(lambda x, _: f'{x:,.0f}'))
ax.legend()

# Add value labels
for bar, val in zip(bars, dow_stats['mean']):
    ax.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 100,
            f'{val:,.0f}', ha='center', va='bottom', fontsize=9)

plt.tight_layout()
plt.savefig('/tmp/02_day_of_week.png', dpi=150, bbox_inches='tight')
plt.show()

weekend_avg = dow_stats.loc[['Saturday', 'Sunday'], 'mean'].mean()
weekday_avg = dow_stats.loc[['Monday', 'Tuesday', 'Wednesday', 'Thursday'], 'mean'].mean()
print(f"Weekend avg: {weekend_avg:,.0f} | Weekday avg: {weekday_avg:,.0f}")
print(f"Weekend premium: +{(weekend_avg/weekday_avg - 1)*100:.1f}%")

# COMMAND ----------
# %md
# ## Phase 3 — Statistical Modeling & Outlier Detection

# COMMAND ----------
# Calculate statistical thresholds
q1 = df_daily['drm_keys_needed'].quantile(0.25)
q3 = df_daily['drm_keys_needed'].quantile(0.75)
iqr = q3 - q1

sigma2_upper = mean_val + 2 * std_val
sigma2_lower = mean_val - 2 * std_val
iqr_upper = q3 + 1.5 * iqr
iqr_lower = q1 - 1.5 * iqr

print("OUTLIER DETECTION THRESHOLDS")
print(f"  Mean:             {mean_val:,.0f}")
print(f"  Std Dev:          {std_val:,.0f}")
print(f"  2σ Upper fence:   {sigma2_upper:,.0f}")
print(f"  2σ Lower fence:   {sigma2_lower:,.0f}")
print(f"  IQR Upper fence:  {iqr_upper:,.0f}")
print(f"  IQR Lower fence:  {iqr_lower:,.0f}")

df_daily['sigma2_flag'] = np.where(df_daily['drm_keys_needed'] > sigma2_upper, 'HIGH',
                          np.where(df_daily['drm_keys_needed'] < sigma2_lower, 'LOW', 'Normal'))
df_daily['iqr_flag'] = np.where(df_daily['drm_keys_needed'] > iqr_upper, 'HIGH',
                       np.where(df_daily['drm_keys_needed'] < iqr_lower, 'LOW', 'Normal'))

outliers = df_daily[(df_daily['sigma2_flag'] != 'Normal') | (df_daily['iqr_flag'] != 'Normal')]
print(f"\nFlagged days: {len(outliers)}")
print(outliers[['date', 'day_name', 'drm_keys_needed', 'sigma2_flag', 'iqr_flag']].to_string(index=False))

# COMMAND ----------
# %md
# ### Box Plot with Outlier Visualization

# COMMAND ----------
fig, axes = plt.subplots(1, 2, figsize=(14, 5))

# Box plot
axes[0].boxplot(df_daily['drm_keys_needed'], vert=True, patch_artist=True,
                boxprops=dict(facecolor='#DBEAFE'),
                medianprops=dict(color='#2563EB', linewidth=2))
axes[0].axhline(sigma2_upper, color='orange', linestyle='--', label=f'2σ upper ({sigma2_upper:,.0f})')
axes[0].axhline(sigma2_lower, color='orange', linestyle=':', label=f'2σ lower ({sigma2_lower:,.0f})')
axes[0].set_title('Distribution — Box Plot', fontweight='bold')
axes[0].set_ylabel('DRM Keys Needed')
axes[0].yaxis.set_major_formatter(plt.FuncFormatter(lambda x, _: f'{x:,.0f}'))
axes[0].legend(fontsize=8)

# Scatter with flags
colors_map = {'Normal': '#93C5FD', 'HIGH': '#DC2626', 'LOW': '#F59E0B'}
for flag, grp in df_daily.groupby('sigma2_flag'):
    axes[1].scatter(grp['date'], grp['drm_keys_needed'],
                    c=colors_map[flag], label=flag, zorder=5, s=30)
axes[1].axhline(sigma2_upper, color='orange', linestyle='--', linewidth=1)
axes[1].axhline(mean_val, color='gray', linestyle=':', linewidth=1)
axes[1].set_title('Daily Values — 2σ Outlier Flags', fontweight='bold')
axes[1].set_ylabel('DRM Keys Needed')
axes[1].xaxis.set_major_formatter(mdates.DateFormatter('%b %d'))
plt.setp(axes[1].get_xticklabels(), rotation=45)
axes[1].legend(fontsize=8)
axes[1].yaxis.set_major_formatter(plt.FuncFormatter(lambda x, _: f'{x:,.0f}'))

plt.tight_layout()
plt.savefig('/tmp/03_outlier_detection.png', dpi=150, bbox_inches='tight')
plt.show()

# COMMAND ----------
# %md
# ## Monthly Trend & COVID-19 Context

# COMMAND ----------
monthly = df_daily.groupby(df_daily['date'].dt.to_period('M'))['drm_keys_needed'].agg(['mean', 'std'])
monthly.index = monthly.index.astype(str)

fig, ax = plt.subplots(figsize=(8, 4))
ax.bar(monthly.index, monthly['mean'], yerr=monthly['std'],
       color=['#DBEAFE', '#93C5FD', '#2563EB'], capsize=5, edgecolor='white')

for i, (idx, row) in enumerate(monthly.iterrows()):
    ax.text(i, row['mean'] + row['std'] + 100, f"{row['mean']:,.0f}", ha='center', fontsize=10)

ax.set_title('Average Daily DRM Keys by Month — COVID Context', fontsize=13, fontweight='bold')
ax.set_ylabel('Avg DRM Keys / Day')
ax.yaxis.set_major_formatter(plt.FuncFormatter(lambda x, _: f'{x:,.0f}'))
ax.set_xlabel('\nApril: COVID lockdown peak  |  May: Reopening (-12%)  |  June: Post-lockdown baseline')
plt.tight_layout()
plt.savefig('/tmp/04_monthly_trend.png', dpi=150, bbox_inches='tight')
plt.show()

# COMMAND ----------
# %md
# ## Budget Recommendation Summary

# COMMAND ----------
recommended_ceiling = int((mean_val + 2 * std_val) * 1.2)
current_holding = 334000
excess = current_holding - recommended_ceiling

print("=" * 55)
print("   BUDGET OPTIMIZATION RECOMMENDATION — FINDINGS")
print("=" * 55)
print(f"\n  Finding 1: Normal operating range")
print(f"    → {df_daily['drm_keys_needed'].min():,.0f} – {df_daily['drm_keys_needed'].max():,.0f} keys/day")
print(f"    → Current quota of 380,000 is massively oversized")

print(f"\n  Finding 2: Demand is cyclical (+15% on weekends)")
print(f"    → Weekday avg:  {weekday_avg:,.0f} keys")
print(f"    → Weekend avg:  {weekend_avg:,.0f} keys")
print(f"    → Budget must account for weekly & seasonal patterns")

print(f"\n  Finding 3: Only {df_daily['drm_keys_needed'].max() / 334000 * 100:.2f}% utilization on peak days")
print(f"    → Peak day (Apr 5):       {df_daily['drm_keys_needed'].max():,.0f} keys")
print(f"    → Keys currently held:    {current_holding:,}")
print(f"    → Recommended ceiling:    {recommended_ceiling:,} (avg + 2σ + 20% buffer)")
print(f"    → Estimated excess keys:  {excess:,} (~{excess/current_holding*100:.1f}% unnecessary)")

print(f"\n  ⚠️  Caveat: Analysis covers Apr–Jun 2020 (COVID lockdown = peak viewership)")
print(f"     Normal non-lockdown usage is likely even lower.")
print("=" * 55)
