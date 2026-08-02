#!/data/data/com.termux/files/usr/bin/python3
"""
seg_alias.py -- shared abbreviation logic for per-segment cd aliases.

Used by:
  .bashrc's _generate_segment_aliases  (mode=generate)
  seg-aliases                          (mode=list)
  seg-alias-set                        (mode=set-override)

Single source of truth so the abbreviation algorithm only has to change in
one place -- the earlier version of this had the logic duplicated inline
in two different bash functions, which is exactly the pattern that caused
drift bugs elsewhere in this project.

ALGORITHM:
  1. Strip everything but letters/digits, lowercase, concatenate all words
     ("dad q&a" -> "dadqa"). If that's already <= 5 chars, use it as-is --
     no need to compress something already short.
  2. Otherwise, per word: keep the first letter, drop vowels from the
     rest, concatenate across words ("book review" -> "bk" + "rvw" ->
     "bkrvw"), then hard-truncate to 5 chars if still too long.
  3. Per-segment overrides (alias_overrides.json) always win over the
     computed abbreviation -- for the cases where the algorithm's guess
     isn't the shorthand you'd actually type.
"""
import json
import os
import re
import sys

HOME = os.path.expanduser("~")
DATA_FILE = f"{HOME}/.shortcuts/.hidden/segments_data.json"
OVERRIDES_FILE = f"{HOME}/.shortcuts/.hidden/alias_overrides.json"
VOWELS = set("aeiou")
MAX_LEN = 5


def load_overrides():
    if os.path.exists(OVERRIDES_FILE):
        try:
            return json.load(open(OVERRIDES_FILE))
        except Exception:
            return {}
    return {}


def abbreviate(name, overrides=None, max_len=MAX_LEN):
    overrides = overrides or {}
    if name in overrides:
        return overrides[name]

    words = re.findall(r"[a-z0-9]+", name.lower())
    plain = "".join(words)
    if len(plain) <= max_len:
        return plain

    parts = []
    for w in words:
        if not w:
            continue
        first, rest = w[0], w[1:]
        consonants = "".join(c for c in rest if c not in VOWELS)
        parts.append(first + consonants)
    abbrev = "".join(parts)
    return abbrev[:max_len]


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "generate"

    if mode == "set-override":
        if len(sys.argv) < 4:
            print("Usage: seg-alias-set \"<segment name>\" <alias>")
            return
        name, custom = sys.argv[2], sys.argv[3]
        overrides = load_overrides()
        overrides[name] = custom
        os.makedirs(os.path.dirname(OVERRIDES_FILE), exist_ok=True)
        json.dump(overrides, open(OVERRIDES_FILE, "w"), indent=2)
        print(f"Override set: '{name}' -> {custom}  (run bashreload to apply)")
        return

    if not os.path.exists(DATA_FILE):
        return
    data = json.load(open(DATA_FILE))
    overrides = load_overrides()

    if mode == "generate":
        # name<TAB>alias per line -- consumed by .bashrc's alias generator
        for s in data["segments"]:
            name = s["name"]
            print(f"{name}\t{abbreviate(name, overrides)}")

    elif mode == "list":
        print(f"{'SEGMENT':<20} {'ALIAS':<8} SOURCE")
        for s in sorted(data["segments"], key=lambda s: s["name"]):
            name = s["name"]
            alias = abbreviate(name, overrides)
            source = "override" if name in overrides else "auto"
            print(f"{name:<20} {alias:<8} {source}")


if __name__ == "__main__":
    main()
