#!/data/data/com.termux/files/usr/bin/python3
"""
segment_manager.py  v3
======================
CRUD system for content segments with counter management,
platform hashtag generation, stats, and growth analysis.

New in v3:
  - Option 7: Bulk counter update (set + copy hashtags in one step)
  - Option 8: Stats dashboard (distribution, top/bottom, velocity)
  - Option 9: Trend ideas (suggests new segments based on patterns)
  - Counter modes: increment / set absolute / bulk-set multiple
  - --quick flag: bypass menu for widget use
  - session.json written on every selection for pipeline integration

CHANGES (this pass):
  - Removed per-platform hashtag generation (PLATFORMS / pick_platform /
    boosters). One hashtag list per segment now, straight from
    segments_data.json, no platform-specific max_tags trimming.
  - Clipboard now copies hashtags only -- no more "<segment><counter>"
    title line.
"""

import json
import os
import subprocess
import sys
from datetime import datetime
from pathlib import Path

DATA_FILE    = os.path.expanduser("~/.shortcuts/.hidden/segments_data.json")
SESSION_FILE = os.path.expanduser("~/.shortcuts/.hidden/session.json")

C = {
    "reset":   "\033[0m",  "green":  "\033[32m", "yellow": "\033[33m",
    "red":     "\033[31m", "cyan":   "\033[36m", "gray":   "\033[90m",
    "bold":    "\033[1m",  "dim":    "\033[2m",  "blue":   "\033[34m",
    "magenta": "\033[35m",
}

TREND_CATEGORIES = {
    "fitness": ["pullups","dips","handstand","lunges","burpees","plank",
                "jumpbox","kettlebell","calisthenics","mobility"],
    "outdoor": ["trail","kayak","bike","swim","camp","summit",
                "via-ferrata","packraft","mtb"],
    "tech":    ["rust","golang","docker","raspberrypi","arduino","llm",
                "api","database","terminal","vim"],
    "edu":     ["bookclub","podcast","language","chess","math","physics"],
}

# =============================================================================
# DATA HELPERS
# =============================================================================

def load_data():
    default = {"segments": []}
    if os.path.exists(DATA_FILE):
        try:
            with open(DATA_FILE) as f:
                return json.load(f)
        except Exception:
            print(f"{C['red']}Data file corrupted -- starting fresh.{C['reset']}")
    return default


def save_data(data):
    os.makedirs(os.path.dirname(DATA_FILE), exist_ok=True)
    with open(DATA_FILE, "w") as f:
        json.dump(data, f, indent=2)


def write_session(segment, counter, mode="incremental"):
    session = {
        "segment":   segment,
        "counter":   counter,
        "mode":      mode,
        "timestamp": datetime.now().isoformat()[:19],
    }
    os.makedirs(os.path.dirname(SESSION_FILE), exist_ok=True)
    with open(SESSION_FILE, "w") as f:
        json.dump(session, f, indent=2)


def copy_to_clipboard(text):
    try:
        subprocess.run(["termux-clipboard-set"],
                       input=text.encode(), check=True, timeout=5)
        return True
    except Exception:
        return False


def get_sorted(segments, reverse=True):
    return sorted(segments, key=lambda s: s["counter"], reverse=reverse)


def badge(counter):
    if counter == 0:       return f"{C['red']}[NEW]{C['reset']}"
    if counter >= 100:     return f"{C['magenta']}[ELITE]{C['reset']}"
    if counter >= 50:      return f"{C['yellow']}[HOT]{C['reset']}"
    return ""


def print_seg(s, idx=None):
    b      = badge(s["counter"])
    prefix = f"{idx:2d}. " if idx is not None else "    "
    print(f"{prefix}{C['cyan']}{s['id']:3d}.{C['reset']} "
          f"[{s['counter']:3d}] {C['bold']}{s['name']:14}{C['reset']} "
          f"- {s.get('short_desc','')[:40]} {b}")


# =============================================================================
# CLIPBOARD
# =============================================================================

def build_clipboard_block(seg):
    """Hashtags only -- no segment/counter title line."""
    return " ".join(seg.get("hashtags", []))


def do_copy(seg):
    block = build_clipboard_block(seg)
    print(f"\n{C['bold']}{'='*52}{C['reset']}")
    print(f"  {C['bold']}{seg['name'].upper()}{C['reset']}  "
          f"#{seg['counter']}  {badge(seg['counter'])}")
    print(f"  {C['cyan']}Tags:{C['reset']} {C['dim']}{block[:80]}"
          f"{'...' if len(block) > 80 else ''}{C['reset']}")
    print(f"{C['bold']}{'='*52}{C['reset']}")
    ok = copy_to_clipboard(block)
    if ok:
        print(f"{C['green']}Copied! Hashtags ready to paste.{C['reset']}")
    else:
        print(f"{C['yellow']}Clipboard unavailable.\n{block}{C['reset']}")
    return ok


# =============================================================================
# QUICK-COPY  (--quick flag / widget)
# =============================================================================

def quick_copy_mode(data):
    hot = sorted([s for s in data["segments"] if s["counter"] >= 50],
                 key=lambda s: -s["counter"])
    print(f"\n{C['bold']}{C['cyan']}QUICK COPY{C['reset']}  "
          f"{C['gray']}hot segments{C['reset']}\n")
    if not hot:
        print(f"{C['yellow']}No hot segments yet.{C['reset']}")
        return
    for i, s in enumerate(hot, 1):
        print(f"  {C['cyan']}{i}.{C['reset']} "
              f"{C['bold']}{s['name']:<14}{C['reset']} "
              f"{C['gray']}#{s['counter']}{C['reset']}")
    print()
    raw = input(f"{C['gray']}Pick (1-{len(hot)}): {C['reset']}").strip()
    if not raw.isdigit() or not (1 <= int(raw) <= len(hot)):
        print("Cancelled."); return
    seg = hot[int(raw) - 1]
    do_copy(seg)
    seg["counter"] += 1
    write_session(seg["name"], seg["counter"])
    save_data(data)
    input(f"\n{C['gray']}Enter to close...{C['reset']}")


# =============================================================================
# OPTION 1: Search and Copy
# =============================================================================

def search_and_copy(data):
    search   = input(f"{C['gray']}Search (Enter=all): {C['reset']}").strip().lower()
    filtered = [s for s in data["segments"]
                if not search
                or search in s["name"].lower()
                or search in s.get("short_desc","").lower()]
    filtered = get_sorted(filtered)
    if not filtered:
        print(f"{C['yellow']}No matches.{C['reset']}"); input("Enter..."); return
    print(f"\n{C['gray']}Results:{C['reset']}")
    for i, s in enumerate(filtered, 1):
        print_seg(s, i)
    try:
        seg = filtered[int(input(f"\n{C['gray']}Pick: {C['reset']}")) - 1]
    except Exception:
        print(f"{C['red']}Invalid.{C['reset']}"); input("Enter..."); return
    do_copy(seg)
    seg["counter"] += 1
    write_session(seg["name"], seg["counter"])
    save_data(data)
    input("\nEnter...")


# =============================================================================
# OPTION 3: Add series
# =============================================================================

def add_series(data):
    name = input("Name: ").strip().lower()
    if any(s["name"] == name for s in data["segments"]):
        print(f"{C['yellow']}Already exists.{C['reset']}"); return
    short_desc = input("Short desc: ").strip()
    full_desc  = input("Full desc (Enter=same): ").strip() or short_desc
    tags_str   = input("Hashtags (space-sep): ").strip()
    hashtags   = [t if t.startswith("#") else "#"+t
                  for t in tags_str.split()][:15]
    new_id = max((s["id"] for s in data["segments"]), default=0) + 1
    data["segments"].append({
        "id": new_id, "name": name, "short_desc": short_desc,
        "full_desc": full_desc, "counter": 0, "hashtags": hashtags
    })
    save_data(data)
    print(f"{C['green']}Added: {name} (ID {new_id}){C['reset']}")
    input("Enter...")


# =============================================================================
# OPTION 4: Edit series  (enhanced counter options)
# =============================================================================

def edit_series(data):
    for s in get_sorted(data["segments"]): print_seg(s)
    try:
        sid = int(input(f"\n{C['gray']}ID to edit: {C['reset']}"))
        seg = next((s for s in data["segments"] if s["id"] == sid), None)
        if not seg: raise ValueError
    except Exception:
        print(f"{C['red']}Not found.{C['reset']}"); input("Enter..."); return

    print(f"\nEditing: {C['bold']}{seg['name']}{C['reset']}  "
          f"counter={seg['counter']}\n")

    seg["name"]       = input(f"Name        [{seg['name']}]: "
                               ).strip() or seg["name"]
    seg["short_desc"] = input(f"Short desc  [{seg['short_desc']}]: "
                               ).strip() or seg["short_desc"]
    seg["full_desc"]  = input(f"Full desc   [{seg.get('full_desc','')}]: "
                               ).strip() or seg.get("full_desc","")
    new_tags = input(f"Hashtags    [{' '.join(t.lstrip('#') for t in seg['hashtags'])}]: "
                     ).strip()
    if new_tags:
        seg["hashtags"] = [t if t.startswith("#") else "#"+t
                           for t in new_tags.split()][:15]

    print(f"\n{C['gray']}Counter options:{C['reset']}")
    print(f"  i   increment +1  (current: {seg['counter']})")
    print(f"  N   set to exact number")
    print(f"  +N  add N to current")
    print(f"  s   skip")
    cnt = input(f"{C['gray']}Counter ({seg['counter']}): {C['reset']}").strip()
    if cnt == "i":
        seg["counter"] += 1
    elif cnt.startswith("+") and cnt[1:].isdigit():
        seg["counter"] += int(cnt[1:])
    elif cnt.isdigit():
        seg["counter"] = int(cnt)

    save_data(data)
    print(f"{C['green']}Updated.{C['reset']}")
    input("Enter...")


# =============================================================================
# OPTION 5: Delete
# =============================================================================

def delete_series(data):
    for s in get_sorted(data["segments"]): print_seg(s)
    try:
        sid = int(input(f"\n{C['gray']}ID to delete: {C['reset']}"))
        seg = next((s for s in data["segments"] if s["id"] == sid), None)
        if seg and input(f"Delete {seg['name']}? (yes/no): "
                         ).strip().lower() == "yes":
            data["segments"].remove(seg)
            save_data(data)
            print(f"{C['green']}Deleted.{C['reset']}")
    except Exception:
        print(f"{C['red']}Cancelled.{C['reset']}")
    input("Enter...")


# =============================================================================
# OPTION 6: List all
# =============================================================================

def list_all(data):
    segs = get_sorted(data["segments"])
    print(f"\n{C['gray']}All segments -- most to least used:{C['reset']}\n")
    for s in segs: print_seg(s)
    total = sum(s["counter"] for s in segs)
    print(f"\n{C['gray']}Total posts logged: {total}{C['reset']}")
    input("\nEnter...")


# =============================================================================
# OPTION 7: Bulk counter update  (NEW)
# =============================================================================
# Use case: uploaded 15 pistol clips today, want to set counter to reflect
# reality without incrementing 15x through the copy flow.

def bulk_counter_update(data):
    print(f"\n{C['bold']}{C['cyan']}Bulk Counter Update{C['reset']}")
    print(f"{C['gray']}Mass upload: set counter + copy hashtags in one step.{C['reset']}\n")

    segs = get_sorted(data["segments"])
    for i, s in enumerate(segs, 1): print_seg(s, i)

    try:
        seg = segs[int(input(f"\n{C['gray']}Pick segment: {C['reset']}")) - 1]
    except Exception:
        print(f"{C['red']}Invalid.{C['reset']}"); input("Enter..."); return

    old = seg["counter"]
    print(f"\n{C['bold']}{seg['name']}{C['reset']} -- current: "
          f"{C['cyan']}{old}{C['reset']}")
    print(f"  N   set to exact number  |  +N  add N  |  s  skip")

    raw = input(f"{C['gray']}Counter: {C['reset']}").strip()
    if raw.startswith("+") and raw[1:].isdigit():
        seg["counter"] += int(raw[1:])
    elif raw.isdigit():
        seg["counter"] = int(raw)
    elif raw == "s":
        print("Skipped."); input("Enter..."); return
    else:
        print("Cancelled."); input("Enter..."); return

    diff = seg["counter"] - old
    print(f"\n{C['green']}{seg['name']}: {old} -> "
          f"{seg['counter']} (+{diff}){C['reset']}")

    if input("\nCopy hashtags now? (y/n, Enter=y): ").strip().lower() != "n":
        do_copy(seg)

    write_session(seg["name"], seg["counter"])
    save_data(data)
    print(f"{C['green']}Saved.{C['reset']}")
    input("Enter...")


# =============================================================================
# OPTION 8: Stats dashboard  (NEW)
# =============================================================================

def stats_dashboard(data):
    counters = [s["counter"] for s in data["segments"] if s["counter"] > 0]
    if not counters:
        print("No data yet."); input("Enter..."); return

    n        = len(counters)
    total    = sum(counters)
    mean     = total / n
    sorted_c = sorted(counters)
    median   = (sorted_c[n//2] if n % 2
                else (sorted_c[n//2-1]+sorted_c[n//2])/2)
    variance = sum((c-mean)**2 for c in counters) / n
    std_dev  = variance ** 0.5
    cv       = std_dev / mean * 100 if mean else 0

    print(f"\n{C['bold']}{C['cyan']}Stats Dashboard{C['reset']}\n")
    print(f"  Segments:       {n}")
    print(f"  Total posts:    {total}")
    print(f"  Mean:           {mean:.1f}")
    print(f"  Median:         {median:.1f}")
    print(f"  Std deviation:  {std_dev:.1f}")
    print(f"  CV:             {cv:.1f}%  "
          f"{C['gray']}(lower = more balanced){C['reset']}")

    print(f"\n  {C['yellow']}HOT (gte 50):{C['reset']}")
    for s in data["segments"]:
        if s["counter"] >= 50:
            bar = "#" * min(s["counter"]//10, 30)
            print(f"    {s['name']:<16} {s['counter']:>4}  {bar}")

    print(f"\n  {C['gray']}Distribution:{C['reset']}")
    for (lo,hi),label in [((0,10),"0-9"),((10,25),"10-24"),
                           ((25,50),"25-49"),((50,100),"50-99"),
                           ((100,9999),"100+")]:
        ct  = sum(1 for c in counters if lo <= c < hi)
        bar = "#" * ct
        print(f"    {label:>7}  {bar:<20} {ct}")

    print(f"\n  {C['dim']}Law of large numbers: CV={cv:.0f}% will decrease "
          f"as total posts grow.{C['reset']}")
    print(f"  {C['dim']}Target CV < 50% for a balanced multi-segment channel.{C['reset']}")
    input("\nEnter...")


# =============================================================================
# OPTION 9: Trend ideas  (NEW)
# =============================================================================

def trend_ideas(data):
    existing = {s["name"].lower() for s in data["segments"]}
    print(f"\n{C['bold']}{C['cyan']}Segment Trend Ideas{C['reset']}\n")
    print(f"{C['gray']}Current: {', '.join(sorted(existing))}{C['reset']}\n")

    for category, ideas in TREND_CATEGORIES.items():
        new = [i for i in ideas if i not in existing]
        if new:
            print(f"  {C['cyan']}{category.upper()}{C['reset']}")
            for idea in new[:4]:
                print(f"    + {idea}")
    print()

    print(f"{C['gray']}Growth notes:{C['reset']}")
    print(f"  {C['dim']}1. Niche clusters: related segments build platform identity.{C['reset']}")
    print(f"  {C['dim']}2. Tech crossover: code+bash = unique vs pure fitness creators.{C['reset']}")
    print(f"  {C['dim']}3. Law of large numbers: 5 segments x 50 posts > 1 x 250.{C['reset']}")
    print(f"  {C['dim']}4. Future: YouTube Data API for real keyword search volume.{C['reset']}")

    add_now = input(f"\n{C['gray']}Add a segment now? (name or Enter to skip): "
                    ).strip().lower()
    if add_now and add_now not in existing:
        short_desc = input("Short desc: ").strip()
        tags_str   = input("Hashtags: ").strip()
        hashtags   = [t if t.startswith("#") else "#"+t
                      for t in tags_str.split()][:15]
        new_id = max((s["id"] for s in data["segments"]), default=0) + 1
        data["segments"].append({
            "id": new_id, "name": add_now, "short_desc": short_desc,
            "full_desc": short_desc, "counter": 0, "hashtags": hashtags
        })
        save_data(data)
        print(f"{C['green']}Added: {add_now}{C['reset']}")
    input("\nEnter...")


# =============================================================================
# MAIN
# =============================================================================

def clear(): os.system("clear")


def header(data):
    segs   = data.get("segments", [])
    total  = sum(s["counter"] for s in segs)
    hot_ct = sum(1 for s in segs if s["counter"] >= 50)
    print(f"\n{C['bold']}{C['cyan']}{'='*52}{C['reset']}")
    print(f"{C['bold']}{C['cyan']}  SEGMENT MANAGER  v3{C['reset']}")
    print(f"{C['bold']}{C['cyan']}{'='*52}{C['reset']}")
    print(f"  {C['gray']}Segments: {len(segs)}  "
          f"Hot: {hot_ct}  Total posts: {total}{C['reset']}\n")


def main():
    data = load_data()
    if "--quick" in sys.argv:
        quick_copy_mode(data); return

    menu = {
        "1": ("Search and Copy",   search_and_copy),
        "2": ("Quick Copy (hot)",  quick_copy_mode),
        "3": ("Add series",        add_series),
        "4": ("Edit series",       edit_series),
        "5": ("Delete series",     delete_series),
        "6": ("List all",          list_all),
        "7": ("Bulk counter",      bulk_counter_update),
        "8": ("Stats dashboard",   stats_dashboard),
        "9": ("Trend ideas",       trend_ideas),
    }

    while True:
        clear(); header(data)
        for k, (label, _) in menu.items():
            extras = {
                "1": "hashtags to clipboard",
                "2": "hot segments, 1 input",
                "4": "name / desc / hashtags / counter",
                "7": "mass upload -- set counter + copy",
                "8": "distribution, velocity, law of large numbers",
                "9": "suggest new segments for growth",
            }
            hint = f"  {C['gray']}({extras[k]}){C['reset']}" if k in extras else ""
            print(f" {C['cyan']}{k}.{C['reset']}  {label}{hint}")
        print(f" {C['cyan']}q.{C['reset']}  Quit\n")

        choice = input(f"{C['gray']}> {C['reset']}").strip().lower()
        if choice == "q": break
        if choice in menu:
            menu[choice][1](data)

    print(f"{C['green']}Goodbye!{C['reset']}\n")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print(f"\n{C['green']}Goodbye!{C['reset']}")
