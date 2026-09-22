#!/data/data/com.termux/files/usr/bin/python3
"""hwbench_plot.py — charts + summary tables from hwbench2 CSVs.

Usage:
    hwbench_plot.py run1.csv [run2.csv ...] [--outdir DIR]

Needs: matplotlib  (pkg install python matplotlib)
Without it, prints the text summary and exits.
"""
import argparse
import csv
import math
import os
import sys
from collections import defaultdict
from datetime import datetime


def fnum(x):
    try:
        return float(x)
    except (TypeError, ValueError):
        return None


def mean(xs):
    xs = list(xs)
    return sum(xs) / len(xs) if xs else float("nan")


def stdev(xs):
    xs = list(xs)
    n = len(xs)
    if n < 2:
        return 0.0
    m = mean(xs)
    return math.sqrt(sum((x - m) ** 2 for x in xs) / (n - 1))


def load(paths):
    rows = []
    for p in paths:
        with open(p, newline="") as fh:
            for r in csv.DictReader(fh):
                r["_file"] = p
                rows.append(r)
    return rows


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("csvs", nargs="+")
    ap.add_argument("--outdir", default=None)
    a = ap.parse_args()

    rows = load(a.csvs)
    if not rows:
        print("no rows found")
        sys.exit(1)

    outdir = a.outdir or os.path.expanduser(
        "~/storage/shared/Export/hwbench_plots_" + datetime.now().strftime("%Y%m%d_%H%M%S"))
    os.makedirs(outdir, exist_ok=True)

    ok = [r for r in rows if r.get("result") == "OK"]

    # ---- text summary per cell ----
    cells_ok = defaultdict(list)
    cells_all = defaultdict(list)
    for r in rows:
        key = (r["device"], r["codec"], r["path"], r["res"])
        cells_all[key].append(r)
        if r["result"] == "OK":
            cells_ok[key].append(r)

    lines = [f"{'device':12} {'codec':5} {'path':7} {'res':6} "
             f"{'n_ok/n':9} {'succ%':6} {'mean_fps':9} {'sd_fps':7}"]
    for key in sorted(cells_all):
        rs = cells_ok[key]
        fps = [v for v in (fnum(r["fps"]) for r in rs) if v is not None]
        succ = 100 * len(rs) / len(cells_all[key])
        lines.append(f"{key[0]:12} {key[1]:5} {key[2]:7} {key[3]:6} "
                     f"{len(rs)}/{len(cells_all[key]):<9} {succ:5.1f}% "
                     f"{mean(fps):8.1f} {stdev(fps):6.1f}")
    summary = "\n".join(lines)
    print(summary)
    with open(os.path.join(outdir, "summary.txt"), "w") as fh:
        fh.write(summary + "\n")

    # input-sha consistency check across devices (comparability guard)
    shas = defaultdict(set)
    for r in rows:
        if r.get("input_sha256"):
            shas[r["res"]].add(r["input_sha256"][:12])
    for res, s in sorted(shas.items()):
        if len(s) > 1:
            print(f"WARNING: {res} inputs differ across runs: {sorted(s)} "
                  f"— cross-device comparison is confounded")

    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
    except ImportError:
        print("matplotlib not installed — summary only. Run: pkg install python matplotlib")
        return

    # ---- fig1: mean fps ± stdev, per codec ----
    for codec in sorted({r["codec"] for r in rows}):
        ks = sorted(k for k in cells_ok if k[1] == codec)
        if not ks:
            continue
        labels = [f"{k[0]}\n{k[2]}" for k in ks]
        ms, ss = [], []
        for k in ks:
            vals = [v for v in (fnum(r["fps"]) for r in cells_ok[k]) if v is not None]
            ms.append(mean(vals))
            ss.append(stdev(vals))
        fig, ax = plt.subplots(figsize=(max(8, len(ks) * 1.3), 5))
        ax.bar(labels, ms, yerr=ss, capsize=4)
        ax.set_title(f"Mean encode fps ± stdev — {codec} (OK runs)")
        ax.set_ylabel("fps")
        fig.tight_layout()
        fig.savefig(os.path.join(outdir, f"fig1_fps_{codec}.png"), dpi=120)
        plt.close(fig)

    # ---- fig2: throttling curves (fps vs sustained run #) ----
    fig, ax = plt.subplots(figsize=(9, 5))
    for dev in sorted({r["device"] for r in rows}):
        for path in ("hw_enc", "sw", "hw_dec"):
            pts = [(int(r["sustained_idx"]), fnum(r["fps"]))
                   for r in ok
                   if r["device"] == dev and r["path"] == path
                   and r["run_kind"] == "sustained" and r["sustained_idx"]
                   and fnum(r["fps"]) is not None]
            if not pts:
                continue
            by_idx = defaultdict(list)
            for i, v in pts:
                by_idx[i].append(v)
            xs = sorted(by_idx)
            ax.plot(xs, [mean(by_idx[i]) for i in xs], marker="o",
                    label=f"{dev}/{path}")
    ax.set_xlabel("sustained run #")
    ax.set_ylabel("fps")
    ax.set_title("Throttling curves — fps across sustained runs")
    ax.legend()
    fig.tight_layout()
    fig.savefig(os.path.join(outdir, "fig2_throttling.png"), dpi=120)
    plt.close(fig)

    # ---- fig3: skin temp vs sustained run # ----
    fig, ax = plt.subplots(figsize=(9, 5))
    for dev in sorted({r["device"] for r in rows}):
        pts = [(int(r["sustained_idx"]), fnum(r["temp_c_end"]))
               for r in ok
               if r["device"] == dev and r["run_kind"] == "sustained"
               and r["sustained_idx"] and fnum(r["temp_c_end"]) is not None]
        if not pts:
            continue
        by_idx = defaultdict(list)
        for i, v in pts:
            by_idx[i].append(v)
        xs = sorted(by_idx)
        ax.plot(xs, [mean(by_idx[i]) for i in xs], marker="o", label=dev)
    ax.set_xlabel("sustained run #")
    ax.set_ylabel("skin temp °C (end of run)")
    ax.set_title("Thermal soak — skin temperature across sustained runs")
    ax.legend()
    fig.tight_layout()
    fig.savefig(os.path.join(outdir, "fig3_thermal.png"), dpi=120)
    plt.close(fig)

    # ---- fig4: battery drop per cell ----
    keys = sorted(cells_all)
    labels = [f"{k[0]}\n{k[1]}/{k[2]}" for k in keys]
    drops = []
    for k in keys:
        d = 0.0
        for r in cells_all[k]:
            s, e = fnum(r["batt_start"]), fnum(r["batt_end"])
            if s is not None and e is not None:
                d += max(0.0, s - e)
        drops.append(d)
    fig, ax = plt.subplots(figsize=(max(8, len(keys) * 1.1), 5))
    ax.bar(labels, drops)
    ax.set_title("Battery drain per cell (sum of per-run % drops)")
    ax.set_ylabel("battery %")
    fig.tight_layout()
    fig.savefig(os.path.join(outdir, "fig4_battery.png"), dpi=120)
    plt.close(fig)

    print(f"charts + summary written to {outdir}")


if __name__ == "__main__":
    main()
