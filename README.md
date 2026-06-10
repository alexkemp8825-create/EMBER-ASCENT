# EMBER ASCENT

A roguelike deckbuilder built in Godot 4.x. Climb the Living Tower, fight enemies with cards, collect relics, and conquer both acts to win.

## Requirements

- [Godot Engine 4.x](https://godotengine.org/download) (4.0 or newer; tested with 4.3+)

## How to Run

1. Clone or pull the latest `main` branch.
2. Open Godot 4.x and click **Import**.
3. Select the `project.godot` file in the project root.
4. Press **F5** (or click the Play button) to launch the game.

The main scene is `scenes/main/Main.tscn`.

**Verify you have the latest build:** the main menu should show `Build 0.1.1-map-fix` at the bottom. If you still see "Map placeholder", you are running an old copy — delete the `.godot` cache folder and re-import the project.

## How to Play (Test Build)

1. **Main Menu** — Start a **New Run** or **Continue Run** (save works between rooms on the map).
2. **Class Select** — Pick **Ash Knight** (strength/block) or **Cinder Witch** (burn). Four other classes are placeholders.
3. **Tower Map (The Ember Spire)** — Click an **Enter: ...** button below the map, or click a room node on the map itself.
4. **Combat** — Play cards using energy, gain block, target enemies, then press **End Turn**.
5. **Rewards** — After combat, take gold, a card, or (after bosses) a relic.
6. **Act 2** — Defeat the Act 1 boss to advance; you heal 30% of max HP and climb a new tower.
7. **Victory** — Defeat the Act 2 boss (`ember_regent`) to complete the run. Use **New Run** or **Main Menu** on the victory screen.

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
