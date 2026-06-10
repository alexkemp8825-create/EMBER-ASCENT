# EMBER ASCENT

A roguelike deckbuilder built in Godot 4.x. Climb the Living Tower, fight enemies with cards, collect relics, and conquer both acts to win.

## Requirements

- [Godot Engine 4.x](https://godotengine.org/download) (4.0 or newer; tested with 4.3+)

## How to Run

1. Clone or pull the latest `main` branch.
2. Open Godot 4.x and click **Import**.
3. Select the `project.godot` file in the project root.
4. Press **F5** (Run Project) — **not F6** (Run Current Scene).

The main scene is `scenes/main/Main.tscn`.

**Verify you have the latest build:** the main menu should show `Build 0.1.2-launch-fix` and the window title should say `EMBER ASCENT 0.1.2-launch-fix`. If you only see three buttons with no build text, you are on an old copy — pull latest `main`, delete the `.godot` folder, and re-import.

## How to Play (Test Build)

1. **Main Menu** — Start a **New Run** or **Continue Run** (save works between rooms on the map).
2. **Class Select** — Pick **Ash Knight** (strength/block) or **Cinder Witch** (burn). Four other classes are placeholders.
3. **First battle** — After class select, you go straight into your first fight (no map screen yet).
4. **Tower Map (The Ember Spire)** — After combat, use the big **Continue** button or click a room on the map.
5. **Combat** — Play cards using energy, gain block, target enemies, then press **End Turn**.
6. **Rewards** — After combat, take gold, a card, or (after bosses) a relic.
7. **Act 2** — Defeat the Act 1 boss to advance; you heal 30% of max HP and climb a new tower.
8. **Victory** — Defeat the Act 2 boss (`ember_regent`) to complete the run. Use **New Run** or **Main Menu** on the victory screen.

Use **Abandon Run** on the map to return to the main menu at any time.

## Project Structure

```
scenes/     # UI and gameplay scenes
scripts/    # Game logic (combat, tower, cards, events, save)
data/       # Reserved for future JSON data (currently inline in scripts)
assets/     # Reserved for art, fonts, and audio
```

## Save File

Runs are saved to `user://ember_ascent_run.save` (Godot user data directory). Progress is saved after completing each room, not mid-combat.

## Current Content

- 2 playable classes (Ash Knight, Cinder Witch)
- 25 cards, 9 enemies, 5 relics, 6 events
- Full tower loop: map → rooms → rewards → boss → Act 2 → final boss
