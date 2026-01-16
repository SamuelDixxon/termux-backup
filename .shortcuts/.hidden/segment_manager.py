import json
import os
import subprocess

DATA_FILE = os.path.expanduser("~/.shortcuts/.hidden/segments_data.json")

def load_data():
    default_data = {
        "segments": [
            {"id": 1, "name": "climb", "short_desc": "rock climbing", "full_desc": "rock climbing", "counter": 1, "hashtags": ["#rockclimbing", "#climbing", "#bouldering", "#adventure", "#outdoors"]},
            {"id": 2, "name": "skip", "short_desc": "jumprope workout", "full_desc": "jumprope", "counter": 1, "hashtags": ["#jumprope", "#skipping", "#fitness", "#cardio", "#workout"]},
            {"id": 3, "name": "piano", "short_desc": "piano playing", "full_desc": "piano", "counter": 1, "hashtags": ["#piano", "#music", "#pianolessons", "#classicalmusic", "#pianoplayer"]},
            {"id": 4, "name": "mcp", "short_desc": "ppl workout", "full_desc": "general workout push pull legs split", "counter": 1, "hashtags": ["#pushpulllegs", "#workout", "#fitness", "#gym", "#strengthtraining"]},
            {"id": 5, "name": "skate", "short_desc": "longboarding", "full_desc": "longboarding", "counter": 1, "hashtags": ["#longboarding", "#skateboarding", "#skate", "#cruising", "#boardlife"]},
            {"id": 6, "name": "code", "short_desc": "coding education", "full_desc": "coding topics and education", "counter": 1, "hashtags": ["#coding", "#programming", "#code", "#learntocode", "#tech"]},
            {"id": 7, "name": "book review", "short_desc": "book reviews", "full_desc": "book reviews and education", "counter": 1, "hashtags": ["#bookreview", "#books", "#reading", "#booklover", "#literature"]},
            {"id": 8, "name": "food", "short_desc": "food challenges", "full_desc": "food challenges and education", "counter": 1, "hashtags": ["#foodchallenge", "#food", "#cooking", "#eats", "#foodie"]},
            {"id": 9, "name": "minecraft", "short_desc": "minecraft builds", "full_desc": "minecraft", "counter": 1, "hashtags": ["#minecraft", "#gaming", "#minecraftbuilds", "#mcpe", "#redstone"]},
            {"id": 10, "name": "trixie", "short_desc": "cat adventures", "full_desc": "cat", "counter": 1, "hashtags": ["#cat", "#trixie", "#catsofinstagram", "#pets", "#feline"]},
            {"id": 11, "name": "technical", "short_desc": "tech testing", "full_desc": "technical topics like a/b testing, product test engineer at microchip", "counter": 1, "hashtags": ["#abtesting", "#tech", "#engineering", "#producttesting", "#microchip"]},
            {"id": 12, "name": "dad q&a2", "short_desc": "dad q&a", "full_desc": "asking my electrical engineering australian dad", "counter": 1, "hashtags": ["#qanda", "#dadadvice", "#electricalengineering", "#australia", "#inspiration"]},
            {"id": 13, "name": "health", "short_desc": "health tech", "full_desc": "new series but going to focus on health and technology", "counter": 1, "hashtags": ["#health", "#healthtech", "#wellness", "#fitness", "#technology"]},
            {"id": 14, "name": "hike", "short_desc": "hiking adventures", "full_desc": "hiking videos", "counter": 1, "hashtags": ["#hiking", "#outdoors", "#adventure", "#trails", "#nature"]},
            {"id": 15, "name": "cisco", "short_desc": "1v1 basketball", "full_desc": "1 on 1 with my coworker francisco", "counter": 1, "hashtags": ["#basketball", "#1on1", "#hoops", "#coworker", "#parkinggarage"]},
            {"id": 16, "name": "ball", "short_desc": "basketball plays", "full_desc": "general basketball", "counter": 1, "hashtags": ["#basketball", "#ball", "#nba", "#hoops", "#basketballlife"]},
            {"id": 17, "name": "tea review", "short_desc": "tea tasting", "full_desc": "tea reviews", "counter": 1, "hashtags": ["#teareview", "#tea", "#tealover", "#teatime", "#herbaltea"]},
            {"id": 18, "name": "foos", "short_desc": "foosball games", "full_desc": "foosball", "counter": 1, "hashtags": ["#foosball", "#tablefootball", "#foos", "#gaming", "#tournament"]},
            {"id": 19, "name": "pistol", "short_desc": "pistol squats", "full_desc": "pistol squats", "counter": 1, "hashtags": ["#squats", "#pistolsquats", "#legs", "#calisthenics", "#core"]}
        ]
    }
    if os.path.exists(DATA_FILE):
        try:
            with open(DATA_FILE, 'r') as f:
                return json.load(f)
        except:
            print("Data file corrupted — starting fresh.")
    return default_data

def save_data(data):
    with open(DATA_FILE, 'w') as f:
        json.dump(data, f, indent=2)

def copy_to_clipboard(text):
    try:
        subprocess.run(["termux-clipboard-set"], input=text.encode(), check=True)
        print("\n✓ Hashtags copied to clipboard!")
    except:
        print("\nManual copy: " + text)

def main():
    data = load_data()
    segments = data["segments"]
    while True:
        print("\n" + "="*70)
        print("SEGMENT HASHTAG MANAGER — Full CRUD")
        print("="*70)
        print("1. Search & Copy Hashtags (auto-increment counter)")
        print("2. Add New Series")
        print("3. Update Series (name, desc, hashtags, set counter)")
        print("4. Delete Series")
        print("5. List All Series")
        print("q. Quit")
        choice = input("\nChoose option: ").strip()

        if choice == 'q':
            print("Goodbye!")
            break

        elif choice == '1':  # Search & Copy with auto-increment
            search = input("\nSearch (or Enter for all): ").strip().lower()
            filtered = [s for s in segments if not search or search in s["name"].lower() or search in s["short_desc"].lower()]
            if not filtered:
                print("No matches.")
                input("Press Enter...")
                continue
            print("\nResults:")
            for i, seg in enumerate(filtered, 1):
                print(f"{i:2d}. [{seg['counter']:2d}] {seg['name']:12} — {seg['short_desc']}")
            num = input("\nChoose number: ").strip()
            try:
                selected = filtered[int(num) - 1]
                print("\n" + "-"*60)
                print(f"Series : {selected['name'].upper()} # {selected['counter']}")
                print(f"Topic  : {selected['full_desc']}")
                hashtags_str = " ".join(selected['hashtags'])
                print(f"\nHashtags:\n{hashtags_str}")
                print("-"*60)
                copy_to_clipboard(hashtags_str)
                # Auto-increment after copy
                selected['counter'] += 1
                save_data(data)
                print(f"Counter auto-incremented → now #{selected['counter']} for next video")
                input("\nPress Enter...")
            except:
                print("Invalid choice.")

        elif choice == '2':  # Add
            name = input("Name (short code): ").strip().lower()
            if any(s["name"] == name for s in segments):
                print("Name already exists.")
                input("Press Enter...")
                continue
            short_desc = input("Short description: ").strip()
            full_desc = input("Full description: ").strip()
            tags_input = input("Hashtags (space separated, no #): ").strip()
            hashtags = ["#" + t for t in tags_input.split() if t][:5]
            new_id = max((s["id"] for s in segments), default=0) + 1
            new_seg = {"id": new_id, "name": name, "short_desc": short_desc, "full_desc": full_desc, "counter": 1, "hashtags": hashtags}
            segments.append(new_seg)
            save_data(data)
            print(f"Added: {name} (ID {new_id})")
            input("Press Enter...")

        elif choice == '3':  # Update
            for s in segments:
                print(f"{s['id']:2d}. [{s['counter']:2d}] {s['name']:12} — {s['short_desc']}")
            try:
                sid = int(input("\nEnter ID to update: "))
                seg = next((s for s in segments if s["id"] == sid), None)
                if not seg:
                    print("ID not found.")
                    input("Press Enter...")
                    continue
                print(f"\nEditing: {seg['name']}")
                new_name = input(f"New name [{seg['name']}]: ").strip() or seg['name']
                new_short = input(f"New short_desc [{seg['short_desc']}]: ").strip() or seg['short_desc']
                new_full = input(f"New full_desc [{seg['full_desc']}]: ").strip() or seg['full_desc']
                new_tags = input(f"New hashtags (space sep, no #) [{ ' '.join(t[1:] for t in seg['hashtags']) }]: ").strip()
                if new_tags:
                    seg['hashtags'] = ["#" + t for t in new_tags.split()][:5]
                counter_input = input(f"Set counter (current: {seg['counter']}) — enter number, 'inc' to +1, or skip: ").strip()
                if counter_input == 'inc':
                    seg['counter'] += 1
                elif counter_input.isdigit():
                    seg['counter'] = int(counter_input)
                seg['name'] = new_name
                seg['short_desc'] = new_short
                seg['full_desc'] = new_full
                save_data(data)
                print("Updated!")
                input("Press Enter...")
            except:
                print("Invalid input.")

        elif choice == '4':  # Delete
            for s in segments:
                print(f"{s['id']:2d}. [{s['counter']:2d}] {s['name']:12} — {s['short_desc']}")
            try:
                sid = int(input("\nEnter ID to delete: "))
                seg = next((s for s in segments if s["id"] == sid), None)
                if seg and input(f"Delete {seg['name']}? (yes/no): ").strip().lower() == 'yes':
                    segments.remove(seg)
                    save_data(data)
                    print("Deleted.")
                input("Press Enter...")
            except:
                print("Invalid.")

        elif choice == '5':  # List all
            print("\nAll series:")
            for s in segments:
                print(f"{s['id']:2d}. [{s['counter']:2d}] {s['name']:12} — {s['short_desc']}")
            input("\nPress Enter...")

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\nGoodbye!")
