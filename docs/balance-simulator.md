# Balance simulator

One-click and headless batches of full EMBER ASCENT runs. A run climbs Act 1 and Act 2. Each act is a 5-floor tower (battle, branch, convergence battle, special room, boss). Completion means defeating The Ember Regent.

The simulator calls the game's own rules:

- `RunState.start_class_run` for class, deck, relic, gold, seed, and tower generation
- `MapNavigator` encounter ids and `TowerState` paths
- `CombatManager` combat, including relics, Burn, and rewards from `RewardManager`
- `RunActions` for rest, forge, observatory, and shrine
- `ShopManager` and `EventManager` for markets and events

It does not play animations or change scenes.

## Run it

From the main menu, press **Balance Sim (100 runs)**. That uses the heuristic policy, Ash Knight, 100 runs, and base seed `1`.

Headless:

```bash
# Fresh clones need one import so Godot registers global classes.
godot --headless --import --path . --quit

godot --headless --path . res://scenes/dev/BalanceSimulator.tscn -- --runs 100 --seed 1 --policy heuristic --class ash_knight
```

Arguments after `--`:

| Flag | Default | Meaning |
| --- | --- | --- |
| `--runs` | `100` | Number of runs per policy |
| `--seed` | `1` | Base seed. Run `i` uses `seed + i * 104729` |
| `--policy` | `heuristic` | `heuristic`, `random`, or `compare` |
| `--class` | `ash_knight` | `ash_knight` or `cinder_witch` |

`compare` runs both policies on the same seeds and prints a side-by-side table.

## Policies

Reward, path, shop, event, and combat choices are pluggable (`scripts/dev/RunPolicy.gd`).

- **heuristic** takes the higher-value card or relic, rests when injured, prays, tempers, scouts, prefers shrines, and plays combat to kill while blocking lethal hits.
- **random** chooses uniformly among legal rooms, card rewards (including skip), relics, and playable cards. Boss rewards cannot be skipped, matching the reward screen. Optional room actions are taken half the time.

Policy rolls use a private RNG. Shuffles, reward generation, and shrine relics still use the game RNG.

## Output

Console markdown, plus:

- `res://reports/latest.md`, `latest.json`, `latest.csv`
- `res://reports/balance_<policy>_<class>_seed<seed>_n<runs>.*`
- the same files under `user://balance_reports/`

JSON and CSV are per-run records for diffing balance changes. The player's save file is restored after the batch.

## Metrics the game does not have

The report leaves these empty and explains why:

- Raise counts
- Souls (gold is reported instead)
- Horde size (encounter size is the spawned enemy count; encounters are a single enemy today)
- Corpse carryover and reserve spawning (carryover is HP, deck power, relics, and gold)
- Failure labels such as "horde wiped" or "outnumbered"

Combat failures are `normal_combat`, `elite_combat`, or `boss_combat`, plus `enemy_attack:<id>` or `status_burn`. Event deaths are `event_lethal:<event_id>`. `combat_stall:<id>` means the 30-turn safety cap, which is not a game rule.
