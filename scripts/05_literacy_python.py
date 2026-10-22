import numpy as np
import pandas as pd
import matplotlib.pyplot as plt

# ---- 1. Variant (same as R) ----
REG_LAST2 = 8
VARIANT = REG_LAST2 % 8
prov = [2, 2, 3, 3, 1, 1, 4, 4][VARIANT]
area = [1, 2, 1, 2, 1, 2, 1, 2][VARIANT]

# ---- 2. Read, merge, filter ----
person = pd.read_csv("data/pslm_person_subset.csv")
hh = pd.read_csv("data/pslm_hh_subset.csv")
hh_small = hh[["hhid", "hhweight", "prov_code", "urban_rural"]]
assert not hh_small["hhid"].duplicated().any()

d = person.merge(hh_small, on="hhid", how="inner")
d = d[(d["prov_code"] == prov) & (d["urban_rural"] == area)]
lit = d[(d["age"] >= 10) & (d["age"] <= 64) & d["literate"].notna()].copy()

# ---- 3. Band table: weighted literacy by band and sex ----
lit["band"] = (lit["age"] // 5) * 5
lit["mid"] = lit["band"] + 2
lit["sex_lab"] = np.where(lit["sex"] == 2, "Women", "Men")
lit["wx"] = lit["literate"] * lit["hhweight"]

tbl = (lit.groupby(["band", "mid", "sex_lab"])
       .agg(n=("literate", "size"), sw=("hhweight", "sum"), swx=("wx", "sum"))
       .reset_index())
tbl["rate"] = 100 * tbl["swx"] / tbl["sw"]
tbl["thin"] = tbl["n"] < 30
tbl[["band", "mid", "sex_lab", "n", "rate", "thin"]].to_csv(
  "figures/band_table_python.csv", index=False)

# ---- 4. Largest gap ----
wide = tbl.pivot(index=["band", "mid"], columns="sex_lab", values="rate").reset_index()
wide["gap"] = wide["Men"] - wide["Women"]
big = wide.loc[wide["gap"].abs().idxmax()]
big_label = f"{int(big['band'])}-{int(big['band']) + 4}"

# ---- 5. Figure ----
colors = {"Women": "#C0392B", "Men": "#2C6FAC"}
fig, ax = plt.subplots(figsize=(9, 5.5))
for s, g in tbl.groupby("sex_lab"):
  g = g.sort_values("mid")
ax.plot(g["mid"], g["rate"], color=colors[s], lw=1.8)
solid, hollow = g[~g["thin"]], g[g["thin"]]
ax.plot(solid["mid"], solid["rate"], "o", color=colors[s], ms=6)
ax.plot(hollow["mid"], hollow["rate"], "o", mfc="white", mec=colors[s], ms=6, mew=1.5)
last = g.iloc[-1]
ax.text(last["mid"] + 0.8, last["rate"], s, color=colors[s],
        fontweight="bold", va="center")

ax.vlines(big["mid"], big["Women"], big["Men"], colors="grey", linestyles="dotted")
ax.text(big["mid"] + 1, (big["Women"] + big["Men"]) / 2,
        f"Largest gap, ages {big_label}:\n{abs(big['gap']):.1f} percentage points",
        fontsize=9, va="center", bbox=dict(fc="white", ec="grey", lw=0.5))

ax.set_xlim(10, 68)
ax.set_ylim(0, 100)
ax.set_xticks(range(12, 63, 5))
ax.set_yticks(range(0, 101, 25))
ax.set_yticklabels([f"{v}%" for v in range(0, 101, 25)])
ax.set_xlabel("Age (midpoint of 5-year band)")
ax.set_ylabel("Weighted literacy rate")
ax.grid(color="#e5e5e5", lw=0.6)
ax.set_axisbelow(True)
for side in ("top", "right"):
  ax.spines[side].set_visible(False)
ax.set_title(f"In rural Punjab the literacy gap between men and women is widest at ages "
             f"{big_label}: {big['Men']:.1f}% of men vs {big['Women']:.1f}% of women",
             fontsize=10, fontweight="bold", loc="left")
fig.text(0.01, 0.01,
         f"Source: PSLM 2019-20 person and household files. Sample: persons aged 10-64 with\n"
         f"non-missing literacy, Punjab rural, n = {len(lit):,}. Weighted by hhweight. "
         f"Hollow markers mark bands with\nfewer than 30 observations for that sex.",
         fontsize=8, ha="left", va="bottom")
fig.subplots_adjust(bottom=0.2)
fig.savefig("figures/literacy_by_age_python.svg")

# ---- 6. Compare with the R table ----
r = pd.read_csv("figures/band_table_R.csv")
cmp = r.merge(tbl, on=["band", "sex_lab"], suffixes=("_R", "_py"))
cmp["diff"] = (cmp["rate_R"] - cmp["rate_py"]).abs()
print("Max difference between R and Python rates:", cmp["diff"].max())
print("All equal to 1 decimal:", bool((cmp["rate_R"].round(1) == cmp["rate_py"].round(1)).all()))
w = tbl[(tbl["band"] == 15) & (tbl["sex_lab"] == "Women")]["rate"].iloc[0]
print(f"Women 15-19 (Python): {w:.1f} | (R): {r[(r.band == 15) & (r.sex_lab == 'Women')]['rate'].iloc[0]:.1f}")
