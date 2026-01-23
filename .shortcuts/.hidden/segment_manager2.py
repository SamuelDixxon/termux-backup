#!/data/data/com.termux/files/usr/bin/python

import json
import os
import subprocess

DATA_FILE = os.path.expanduser("~/.shortcuts/.hidden/segments_data.json")

# ANSI colors (Termux friendly)
C = {
    "reset": "\033[0m",
    "green": "\033[32m",
    "yellow": "\033[33m",
    "red": "\033[31m",
    "cyan": "\033[36m",
    "gray": "\033[90m",
    "bold": "\033[1m",
}

def load_data():
    default_data = {
        "segments": [
            # your original default segments here (I removed them to keep this shorter)
            # paste your full default list back in if the file is missing
        ]
    }
    if os.path.exists(DATA_FILE):
        try:
            with open(DATA_FILE, 'r') as f:
                return json.load(f)
        except Exception:
            print(f"{C['red']}Data file corrupted — starting fresh.{C['reset']}")
    return default_data

def save_data(data):
    os.makedirs(os.path.dirname(DATA_FILE), exist_ok=True)
    with open(DATA_FILE, 'w') as f:
        json.dump(data, f, indent=2)

def copy_to_clipboard(text):
    try:
        subprocess.run(["termux-clipboard-set"], input=text.encode(), check=True)
        print(f"{C['green']}✓ Hashtags copied!{C['reset']}")
    except Exception:
        print(f"{C['yellow']}Clipboard failed — copy manually:{C['reset']}\n{text}")

def get_sorted_segments(segments):
    return sorted(segments, key=lambda s: s["counter"])

def badge(counter):
    if counter == 0:
        return f"{C['red']}[NEW]{C['reset']}"
    if counter >= 50:
        return f"{C['yellow']}[HOT]{C['reset']}"
    return ""

def print_segment(s, index=None):
    badge_str = badge(s["counter"])
    line = (f"{C['cyan']}{s['id']:3d}.{C['reset']} "
            f"[{s['counter']:3d}] {C['bold']}{s['name']:14}{C['reset']} "
            f"— {s['short_desc'][:50]}{'…' if len(s['short_desc']) > 50 else ''} "
            f"{badge_str}")
    if index is not None:
        print(f"{index:2d}. {line}")
    else:
        print(line)

def main():
    data = load_data()
    segments = data["segments"]

    while True:
        print(f"\n{C['bold']}═{'═'*68}{C['reset']}")
        print(f"{C['bold']}  SEGMENT MANAGER  —  sorted by usage (least → most){C['reset']}")
        print(f"{C['bold']}═{'═'*68}{C['reset']}")
        print(" 1.  Search & Copy hashtags (auto +1)")
        print(" 2.  Add new series")
        print(" 3.  Edit series")
        print(" 4.  Delete series")
        print(" 5.  List all (with top/bottom stats)")
        print(" q.  Quit")
        choice = input(f"\n{C['gray']}→{C['reset']} ").strip().lower()

        if choice in ('q', 'quit', 'exit'):
            print(f"{C['green']}Bye!{C['reset']}")
            break

        # ──────────────────────────────────────
        if choice == '1':
            search = input(f"{C['gray']}Search name/desc (Enter = all):{C['reset']} ").strip().lower()
            filtered = [s for s in segments if not search or search in s["name"].lower() or search in s["short_desc"].lower()]
            filtered = get_sorted_segments(filtered)

            if not filtered:
                print(f"{C['yellow']}No matches.{C['reset']}")
                input("Press Enter…")
                continue

            print(f"\n{C['gray']}Results (sorted by usage):{C['reset']}")
            for i, seg in enumerate(filtered, 1):
                print_segment(seg, i)

            try:
                num = int(input(f"\n{C['gray']}Pick number:{C['reset']} "))
                selected = filtered[num - 1]
            except:
                print(f"{C['red']}Invalid.{C['reset']}")
                input("Press Enter…")
                continue

            print(f"\n{C['bold']}{'-'*60}{C['reset']}")
            print(f" {C['bold']}{selected['name'].upper()}{C['reset']}  #{selected['counter']}")
            print(f" {selected['full_desc']}")
            tags = " ".join(selected["hashtags"])
            print(f"\n{tags}")
            print(f"{C['bold']}{'-'*60}{C['reset']}")

            copy_to_clipboard(tags)
            selected["counter"] += 1
            save_data(data)
            print(f"{C['green']}Counter → {selected['counter']}{C['reset']}")
            input("\nPress Enter…")

        # ──────────────────────────────────────
        elif choice == '2':
            name = input("Short code / name: ").strip().lower()
            if any(s["name"] == name for s in segments):
                print(f"{C['yellow']}Name already exists.{C['reset']}")
                continue

            short_desc = input("Short desc: ").strip()
            full_desc  = input("Full desc : ").strip()
            tags_str   = input("Hashtags (space sep, no #): ").strip()
            hashtags   = ["#" + t for t in tags_str.split() if t][:6]

            new_id = max((s["id"] for s in segments), default=0) + 1
            new_seg = {
                "id": new_id,
                "name": name,
                "short_desc": short_desc,
                "full_desc": full_desc,
                "counter": 1,
                "hashtags": hashtags
            }
            segments.append(new_seg)
            save_data(data)
            print(f"{C['green']}Added → {name} (ID {new_id}){C['reset']}")
            input("Press Enter…")

        # ──────────────────────────────────────
        elif choice == '3':
            print(f"\n{C['gray']}All series (sorted by usage):{C['reset']}")
            for s in get_sorted_segments(segments):
                print_segment(s)

            try:
                sid = int(input(f"\n{C['gray']}ID to edit:{C['reset']} "))
                seg = next((s for s in segments if s["id"] == sid), None)
                if not seg:
                    raise ValueError
            except:
                print(f"{C['red']}Not found.{C['reset']}")
                input("Press Enter…")
                continue

            print(f"\nEditing: {C['bold']}{seg['name']}{C['reset']}")
            seg["name"]       = input(f"Name        [{seg['name']}] : ") or seg["name"]
            seg["short_desc"] = input(f"Short desc  [{seg['short_desc']}] : ") or seg["short_desc"]
            seg["full_desc"]  = input(f"Full desc   [{seg['full_desc']}] : ") or seg["full_desc"]

            new_tags = input(f"Hashtags    [{' '.join(t[1:] for t in seg['hashtags'])}] : ").strip()
            if new_tags:
                seg["hashtags"] = ["#" + t for t in new_tags.split()][:6]

            cnt = input(f"Counter     [now {seg['counter']}] (number / 'inc' / skip): ").strip()
            if cnt == "inc":
                seg["counter"] += 1
            elif cnt.isdigit():
                seg["counter"] = int(cnt)

            save_data(data)
            print(f"{C['green']}Updated.{C['reset']}")
            input("Press Enter…")

        # ──────────────────────────────────────
        elif choice == '4':
            print(f"\n{C['gray']}All series (sorted):{C['reset']}")
            for s in get_sorted_segments(segments):
                print_segment(s)

            try:
                sid = int(input(f"\n{C['gray']}ID to delete:{C['reset']} "))
                seg = next((s for s in segments if s["id"] == sid), None)
                if seg and input(f"Really delete {seg['name']}? (yes/no): ").strip().lower() == "yes":
                    segments.remove(seg)
                    save_data(data)
                    print(f"{C['green']}Deleted.{C['reset']}")
            except:
                print(f"{C['red']}Cancelled / invalid.{C['reset']}")
            input("Press Enter…")

        # ──────────────────────────────────────
        elif choice == '5':
            sorted_segs = get_sorted_segments(segments)
            print(f"\n{C['gray']}All series — sorted by counter (least to most):{C['reset']}")
            for s in sorted_segs:
                print_segment(s)

            if sorted_segs:
                print(f"\n{C['yellow']}Least used (bottom 5):{C['reset']}")
                for s in sorted_segs[:5]:
                    print(f"  {s['counter']:3d} × {s['name']}")

                print(f"\n{C['yellow']}Most used (top 5):{C['reset']}")
                for s in sorted_segs[-5:]:
                    print(f"  {s['counter']:3d} × {s['name']}")

            input("\nPress Enter…")

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print(f"\n{C['green']}Goodbye!{C['reset']}")#!/data/data/com.termux/files/usr/bin/python

import json
import os
import subprocess

DATA_FILE = os.path.expanduser("~/.shortcuts/.hidden/segments_data.json")

# ANSI colors (Termux friendly)
C = {
    "reset": "\033[0m",
    "green": "\033[32m",
    "yellow": "\033[33m",
    "red": "\033[31m",
    "cyan": "\033[36m",
    "gray": "\033[90m",
    "bold": "\033[1m",
}

def load_data():
    default_data = {
        "segments": [
            # your original default segments here (I removed them to keep this shorter)
            # paste your full default list back in if the file is missing
        ]
    }
    if os.path.exists(DATA_FILE):
        try:
            with open(DATA_FILE, 'r') as f:
                return json.load(f)
        except Exception:
            print(f"{C['red']}Data file corrupted — starting fresh.{C['reset']}")
    return default_data

def save_data(data):
    os.makedirs(os.path.dirname(DATA_FILE), exist_ok=True)
    with open(DATA_FILE, 'w') as f:
        json.dump(data, f, indent=2)

def copy_to_clipboard(text):
    try:
        subprocess.run(["termux-clipboard-set"], input=text.encode(), check=True)
        print(f"{C['green']}✓ Hashtags copied!{C['reset']}")
    except Exception:
        print(f"{C['yellow']}Clipboard failed — copy manually:{C['reset']}\n{text}")

def get_sorted_segments(segments):
    return sorted(segments, key=lambda s: s["counter"])

def badge(counter):
    if counter == 0:
        return f"{C['red']}[NEW]{C['reset']}"
    if counter >= 50:
        return f"{C['yellow']}[HOT]{C['reset']}"
    return ""

def print_segment(s, index=None):
    badge_str = badge(s["counter"])
    line = (f"{C['cyan']}{s['id']:3d}.{C['reset']} "
            f"[{s['counter']:3d}] {C['bold']}{s['name']:14}{C['reset']} "
            f"— {s['short_desc'][:50]}{'…' if len(s['short_desc']) > 50 else ''} "
            f"{badge_str}")
    if index is not None:
        print(f"{index:2d}. {line}")
    else:
        print(line)

def main():
    data = load_data()
    segments = data["segments"]

    while True:
        print(f"\n{C['bold']}═{'═'*68}{C['reset']}")
        print(f"{C['bold']}  SEGMENT MANAGER  —  sorted by usage (least → most){C['reset']}")
        print(f"{C['bold']}═{'═'*68}{C['reset']}")
        print(" 1.  Search & Copy hashtags (auto +1)")
        print(" 2.  Add new series")
        print(" 3.  Edit series")
        print(" 4.  Delete series")
        print(" 5.  List all (with top/bottom stats)")
        print(" q.  Quit")
        choice = input(f"\n{C['gray']}→{C['reset']} ").strip().lower()

        if choice in ('q', 'quit', 'exit'):
            print(f"{C['green']}Bye!{C['reset']}")
            break

        # ──────────────────────────────────────
        if choice == '1':
            search = input(f"{C['gray']}Search name/desc (Enter = all):{C['reset']} ").strip().lower()
            filtered = [s for s in segments if not search or search in s["name"].lower() or search in s["short_desc"].lower()]
            filtered = get_sorted_segments(filtered)

            if not filtered:
                print(f"{C['yellow']}No matches.{C['reset']}")
                input("Press Enter…")
                continue

            print(f"\n{C['gray']}Results (sorted by usage):{C['reset']}")
            for i, seg in enumerate(filtered, 1):
                print_segment(seg, i)

            try:
                num = int(input(f"\n{C['gray']}Pick number:{C['reset']} "))
                selected = filtered[num - 1]
            except:
                print(f"{C['red']}Invalid.{C['reset']}")
                input("Press Enter…")
                continue

            print(f"\n{C['bold']}{'-'*60}{C['reset']}")
            print(f" {C['bold']}{selected['name'].upper()}{C['reset']}  #{selected['counter']}")
            print(f" {selected['full_desc']}")
            tags = " ".join(selected["hashtags"])
            print(f"\n{tags}")
            print(f"{C['bold']}{'-'*60}{C['reset']}")

            copy_to_clipboard(tags)
            selected["counter"] += 1
            save_data(data)
            print(f"{C['green']}Counter → {selected['counter']}{C['reset']}")
            input("\nPress Enter…")

        # ──────────────────────────────────────
        elif choice == '2':
            name = input("Short code / name: ").strip().lower()
            if any(s["name"] == name for s in segments):
                print(f"{C['yellow']}Name already exists.{C['reset']}")
                continue

            short_desc = input("Short desc: ").strip()
            full_desc  = input("Full desc : ").strip()
            tags_str   = input("Hashtags (space sep, no #): ").strip()
            hashtags   = ["#" + t for t in tags_str.split() if t][:6]

            new_id = max((s["id"] for s in segments), default=0) + 1
            new_seg = {
                "id": new_id,
                "name": name,
                "short_desc": short_desc,
                "full_desc": full_desc,
                "counter": 1,
                "hashtags": hashtags
            }
            segments.append(new_seg)
            save_data(data)
            print(f"{C['green']}Added → {name} (ID {new_id}){C['reset']}")
            input("Press Enter…")

        # ──────────────────────────────────────
        elif choice == '3':
            print(f"\n{C['gray']}All series (sorted by usage):{C['reset']}")
            for s in get_sorted_segments(segments):
                print_segment(s)

            try:
                sid = int(input(f"\n{C['gray']}ID to edit:{C['reset']} "))
                seg = next((s for s in segments if s["id"] == sid), None)
                if not seg:
                    raise ValueError
            except:
                print(f"{C['red']}Not found.{C['reset']}")
                input("Press Enter…")
                continue

            print(f"\nEditing: {C['bold']}{seg['name']}{C['reset']}")
            seg["name"]       = input(f"Name        [{seg['name']}] : ") or seg["name"]
            seg["short_desc"] = input(f"Short desc  [{seg['short_desc']}] : ") or seg["short_desc"]
            seg["full_desc"]  = input(f"Full desc   [{seg['full_desc']}] : ") or seg["full_desc"]

            new_tags = input(f"Hashtags    [{' '.join(t[1:] for t in seg['hashtags'])}] : ").strip()
            if new_tags:
                seg["hashtags"] = ["#" + t for t in new_tags.split()][:6]

            cnt = input(f"Counter     [now {seg['counter']}] (number / 'inc' / skip): ").strip()
            if cnt == "inc":
                seg["counter"] += 1
            elif cnt.isdigit():
                seg["counter"] = int(cnt)

            save_data(data)
            print(f"{C['green']}Updated.{C['reset']}")
            input("Press Enter…")

        # ──────────────────────────────────────
        elif choice == '4':
            print(f"\n{C['gray']}All series (sorted):{C['reset']}")
            for s in get_sorted_segments(segments):
                print_segment(s)

            try:
                sid = int(input(f"\n{C['gray']}ID to delete:{C['reset']} "))
                seg = next((s for s in segments if s["id"] == sid), None)
                if seg and input(f"Really delete {seg['name']}? (yes/no): ").strip().lower() == "yes":
                    segments.remove(seg)
                    save_data(data)
                    print(f"{C['green']}Deleted.{C['reset']}")
            except:
                print(f"{C['red']}Cancelled / invalid.{C['reset']}")
            input("Press Enter…")

        # ──────────────────────────────────────
        elif choice == '5':
            sorted_segs = get_sorted_segments(segments)
            print(f"\n{C['gray']}All series — sorted by counter (least to most):{C['reset']}")
            for s in sorted_segs:
                print_segment(s)

            if sorted_segs:
                print(f"\n{C['yellow']}Least used (bottom 5):{C['reset']}")
                for s in sorted_segs[:5]:
                    print(f"  {s['counter']:3d} × {s['name']}")

                print(f"\n{C['yellow']}Most used (top 5):{C['reset']}")
                for s in sorted_segs[-5:]:
                    print(f"  {s['counter']:3d} × {s['name']}")

            input("\nPress Enter…")

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print(f"\n{C['green']}Goodbye!{C['reset']}")
