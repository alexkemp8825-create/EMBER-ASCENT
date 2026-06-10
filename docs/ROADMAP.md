# EMBER ASCENT — Development Roadmap

This roadmap tracks gameplay phases and the **Living Tower Memory** meta-progression system. Phases build on each other; Living Tower Memory (LTM) layers cross-run persistence on top of the run loop introduced in Phases 10–16.

## Run loop (current)

```
Main Menu → Class Select → Living Tower Map → Rooms → Combat/Rewards → Save checkpoint → …
```

**Per-run save:** `user://ember_ascent_run.save` (deck, HP, gold, tower layout, act progress)

**Tower memory save:** `user://ember_ascent_legacy.save` (completed run echoes — separate file)

---

## Completed phases

| Phase | Focus | Key systems |
|-------|-------|-------------|
| 10 | Post-combat rewards & relics | `RewardManager`, boss relics |
| 11A | Tower branching & room variety | `TowerGenerator`, elite/event rooms |
| 11B | Shop & gold sinks | `ShopManager`, `ShopScreen` |
| 12 | Save & Continue Run | `SaveManager`, main menu continue |
| 13 | Events system | `EventDatabase`, `EventScreen` |
| 14 | Act 2 & elite battles | Act 2 generation, elite encounters |
| 15 | Cinder Witch (2nd class) | `ClassDatabase`, enemy burn |
| 16 | Card upgrades at the Forge | `ForgeUpgradeManager`, `+` card variants |

---

## Living Tower Memory (LTM)

The tower **remembers** past ascents. Each finished run becomes a **legacy echo** stored outside the active run save. Future towers can spawn **ghost rooms** — optional side branches linked to those echoes.

### LTM sprints (integrated as Phase 17)

| Sprint | Name | What it does | Files |
|--------|------|--------------|-------|
| **LTM-01** | Legacy data foundation | `LegacyRunData`, `LegacyManager` autoload, `ember_ascent_legacy.save` | `scripts/legacy/*` |
| **LTM-02** | Record run endings | Defeat, abandon, and final-act victory call `LegacyManager.finalize_run_end()` | `CombatManager`, `EventScreen`, `MapScreen`, `RewardScreen` |
| **LTM-03** | Ghost rooms on new towers | 1–3 ghost side rooms from legacy pool when generating acts | `GhostRoomPlacer`, `TowerState`, `GhostRoomScreen` |

### What each legacy echo stores

- Class, final HP, result (`victory` / `defeat` / `abandoned`)
- Deck & relic snapshots at run end
- Tower layout snapshot, path taken, floors reached, boss reached
- Ghost display name (e.g. "Fallen Ash Knight")

### Run-end recording rules

| Outcome | When recorded | Screen after |
|---------|---------------|--------------|
| Defeat | HP reaches 0 in combat or event | Defeat screen → main menu |
| Abandon | Player abandons from map | Main menu |
| Victory | Act 2 boss defeated (full run complete) | Victory screen → main menu |
| Act 1 boss | **Not** recorded as legacy — run advances to Act 2 | Map (new act tower) |

### Ghost rooms (LTM-03)

- Placed on floors 2–5 when legacy data exists
- Purple styling on map; optional branch from anchor rooms
- Visiting shows echo summary (deck/relic count, ghost name)
- Full ghost **encounters** are a future sprint (LTM-04)

### Integration with other phases

| Phase feature | Memory interaction |
|---------------|-------------------|
| Forge upgrades (`+` cards) | Upgraded card IDs stored in `deck_snapshot` |
| Shop / deck thinning | Deck changes reflected in next legacy echo |
| Cinder Witch | `ghost_name` mapping for `cinder_witch` class |
| Save & Continue | Active run save unchanged; legacy only on run **end** |
| Act 2 | Ghost strength scales with `final_floor` / `boss_reached` |

---

## Upcoming phases

| Phase | Focus | Notes |
|-------|-------|-------|
| **17** | Living Tower Memory (LTM-01–03) | This phase — cross-run persistence + ghost rooms |
| 18 | LTM-04 ghost encounters | Fight echo decks; rewards from ghost strength |
| 19 | Rest site options | Heal / meditate / ??? beyond current rest |
| 20 | Shrine boons | Permanent or run-long blessings |
| 21 | Observatory lore | Meta hints from legacy run count |

---

## Branch naming

Cloud agent branches: `cursor/<descriptive-name>-3848`

Reference implementation for LTM (pre–phase 14): `cursor/living-tower-sprint-01-ec3b` (PR #9)

---

## Version tags

| Version | Milestone |
|---------|-----------|
| `0.1.0-phase-16` | Forge card upgrades |
| `0.1.0-phase-17` | Living Tower Memory |
