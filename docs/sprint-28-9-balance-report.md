# Sprint 28.9 — Run upgrades, stacking, and balance

EMBER ASCENT did not previously have Soul, corpses, Raise, or minions. Those systems are now combat rules that sit on the existing card fight: energy, block, attacks, burn, enemy intents, and the tower. Post-battle rewards still grant gold, a card (or a boss relic), and now one of three run upgrades.

## Upgrade list

Foundation rewards stay in the pool. The other 17 are the new build upgrades (2–3 per theme).

| Id | Name | Theme | Max stacks | What it hooks |
|---|---|---|---:|---|
| `soul_cache` | Soul Cache | Foundation | 3 | Gain 6 Soul now, and 2 Soul per stack on every victory. |
| `ember_capacity` | Ember Capacity | Foundation | 1 | First turn of each combat has +1 Energy. |
| `ash_reserves` | Ash Reserves | Foundation | 3 | +4 Max HP on take. +3 Block per stack at combat start. |
| `grave_call` | Grave Call | Raise | 2 | Spend corpses at the start of your turn to Raise. |
| `unfinished_rite` | Unfinished Rite | Raise | 1 | The first minion that would die each fight survives at 1 HP and attacks. |
| `chorus_of_ash` | Chorus of Ash | Raise | 2 | Each Raise draws a card, up to one draw per stack each turn. |
| `cinder_corpse` | Cinder Corpse | Corpse Explosion | 3 | Splash 5 damage per stack if another enemy lives; otherwise bank 6 damage per stack as next-fight pyre (cap 16). |
| `pyre_funeral` | Pyre Funeral | Corpse Explosion | 2 | A dead minion deals 6 damage per stack and grants 1 Soul per stack. |
| `chain_ash` | Chain Ash | Corpse Explosion | 1 | Every victory primes 3 Burn on the next fight. Explosions also apply 3 Burn. |
| `hold_the_line` | Hold the Line | Commander | 1 | Keep half your Block (rounded down) between turns. |
| `interpose` | Interpose | Commander | 1 | The first enemy attack each enemy turn hits your lowest-HP minion. |
| `last_ember` | Last Ember | Commander | 1 | Once per combat, a lethal hit leaves you at 1 HP and grants 6 Block. |
| `ember_step` | Ember Step | Movement/Control | 2 | Draw 1 extra card each turn. At 2 stacks, the first Skill each turn costs 1 less. |
| `break_intent` | Break Intent | Movement/Control | 2 | Enemy attacks deal 2 less per stack. The first Strength gain each fight is cut by 2. At 2 stacks, a telegraphed heavy attack deals half. |
| `bone_ranks` | Bone Ranks | Skeleton | 2 | Raise one free Skeleton at combat start. Each stack: Skeletons +3 HP and +1 attack. |
| `rattling_volley` | Rattling Volley | Skeleton | 2 | An Attack that costs 1 or less makes each living Skeleton deal 2 damage per stack. |
| `brute_summons` | Brute Summons | Brute | 2 | Raises spend 2 corpses on a Brute. Without Grave Call, one Brute per combat. Each stack: +4 HP and +2 attack. At 2 stacks, +4 Block when raised. |
| `crushing_swing` | Crushing Swing | Brute | 2 | Attacks that cost 2 or more deal +3 damage per stack, plus 2 if a Brute is alive. |
| `soul_interest` | Soul Interest | Soul Economy | 3 | On victory, 2 Soul per stack plus 1 per 5 Soul held, up to 6 bonus. |
| `tithe_blade` | Tithe Blade | Soul Economy | 2 | A damaging Attack gains 1 Soul per stack. At 12 Soul, the next Attack spends 12 and deals +5. |

Base minions, before those bonuses: Skeleton 6 HP / 2 attack, Brute 14 HP / 6 attack. Corpses cap at 5 and carry between fights. Minions do not.

Act 2's first battle is `hound_pack` (Furnace Hound plus Charred Rat) so a corpse can explode into a living enemy. Other fights are still a single enemy, so Cinder Corpse's usual payoff is the next fight's opening pyre.

## Stacking and offer rules

A post-battle upgrade offer is up to 3 choices.

- No duplicate in one draw. The three buttons are always different upgrades.
- Each upgrade has `max_stacks`. Uniques are 1. Stackable upgrades can be offered again until they hit that cap.
- At max stacks, the upgrade leaves the pool.
- If fewer than 3 legal upgrades remain, the offer is shorter. If none remain, the upgrade row is skipped.
- Skip does not burn the offered upgrades. They can appear again.
- Taking an upgrade adds one stack immediately. Soul Cache and Ash Reserves also apply their on-take Soul or Max HP then.
- Theme weighting is light. A non-foundation theme with total stacks of 2 or more is committed. Its upgrades are drawn at weight 2; everything else, including Soul / capacity / reserves, stays at weight 1. Several themes can be committed at once. This nudges a run toward a build without locking the pool.

The tower map (and the victory panel) lists every upgrade taken, its stack count, Soul, corpses, and the dominant theme. Dominant means the non-foundation theme with the most stacks. Ties list every tied theme. No build stacks yet reads as Unspecialized.

## How the simulator was run

```
godot --headless --path . res://tools/SimulateRuns.tscn -- --runs 2000 --out /tmp/ember_sim_after.json
```

2000 runs per policy, 6000 runs total, after the tuning pass below. The same seed scheme was used for the pre-tune run. Classes alternate Ash Knight and Cinder Witch.

Policies:

- **random** — uniform choice among the three offered upgrades.
- **greedy** — the run is assigned one of the seven build themes and always takes that theme when it is offered. Otherwise it falls back to Ember Capacity, then Ash Reserves, then Soul Cache.
- **smart** — a fixed heuristic. It prefers the theme it has already stacked, pays extra for on-theme synergies (volley once skeletons exist, Crushing Swing once the deck has 2-cost attacks, Chain Ash once an explosion upgrade is owned), and values Block and Last Ember more when HP is low.

Column definitions:

- **Offer rate** — share of reward screens that included the upgrade.
- **Pick rate** — picks per run. Stackable upgrades can be picked more than once, so this is not capped at 1.
- **Pick when offered** — picks divided by offers.
- **Win rate if owned** — runs that ended holding at least one stack. A win is defeating the Act 2 boss.
- **Mean end HP** — HP ratio at the end of the run, with a death counted as 0.

Random pick-when-offered sits on 31–35% for every upgrade. That is the uniform 1-of-3 draw, plus a little noise from theme weighting and from maxed uniques leaving the pool. Offer rate is slightly lower for uniques (about 13%) than for 2-stack upgrades (about 16%) for the same reason.

## Results after tuning

Overall: random **65.7%** wins, mean 5.61 combats. Greedy **63.7%**, mean 5.60. Smart **72.5%**, mean 5.79. Forcing one theme is not better than picking at random. Picking into a synergy is worth about seven points.

### Random (n = 2000, 11229 offers)

| Upgrade | Offer rate | Pick rate | Pick when offered | Win rate if owned | Mean combats | Mean end HP | Runs |
|---|---:|---:|---:|---:|---:|---:|---:|
| `ember_capacity` | 13.5% | 0.26 | 34.6% | 72.3% | 5.86 | 45.3% | 524 |
| `rattling_volley` | 16.0% | 0.31 | 34.4% | 72.9% | 5.77 | 44.0% | 535 |
| `bone_ranks` | 16.1% | 0.31 | 34.4% | 81.7% | 6.16 | 51.0% | 545 |
| `chorus_of_ash` | 16.7% | 0.32 | 34.3% | 68.0% | 5.80 | 41.3% | 557 |
| `break_intent` | 16.1% | 0.31 | 34.0% | 77.3% | 6.00 | 46.1% | 542 |
| `crushing_swing` | 15.8% | 0.30 | 34.0% | 73.3% | 5.95 | 43.5% | 531 |
| `interpose` | 13.2% | 0.25 | 33.9% | 72.5% | 5.84 | 47.3% | 501 |
| `chain_ash` | 13.6% | 0.26 | 33.8% | 72.1% | 5.90 | 44.5% | 517 |
| `pyre_funeral` | 15.6% | 0.29 | 33.7% | 70.7% | 5.93 | 41.8% | 502 |
| `soul_cache` | 14.5% | 0.27 | 33.6% | 69.8% | 5.82 | 42.3% | 494 |
| `brute_summons` | 14.7% | 0.28 | 33.5% | 83.0% | 6.07 | 51.1% | 481 |
| `ember_step` | 15.3% | 0.29 | 33.4% | 73.6% | 5.92 | 45.3% | 507 |
| `cinder_corpse` | 15.9% | 0.30 | 33.1% | 67.8% | 5.86 | 42.1% | 509 |
| `unfinished_rite` | 13.7% | 0.26 | 33.1% | 69.8% | 5.81 | 42.1% | 510 |
| `grave_call` | 15.7% | 0.29 | 33.0% | 80.7% | 6.10 | 49.5% | 493 |
| `last_ember` | 13.1% | 0.24 | 32.7% | 76.8% | 6.05 | 42.7% | 482 |
| `tithe_blade` | 15.3% | 0.28 | 32.6% | 74.5% | 5.93 | 44.2% | 509 |
| `ash_reserves` | 15.5% | 0.28 | 31.7% | 71.7% | 5.85 | 44.2% | 491 |
| `hold_the_line` | 13.9% | 0.25 | 31.6% | 72.9% | 5.93 | 44.1% | 494 |
| `soul_interest` | 15.9% | 0.28 | 31.2% | 70.1% | 5.86 | 42.2% | 481 |

### Greedy (n = 2000, 11192 offers)

Greedy pick rates on Ember Capacity (74.8%), Ash Reserves (67.8%), and Soul Cache (60.4%) are the fallback, not evidence those three are the best cards. When the assigned theme is missing from the three buttons, the policy takes foundation in that order. Their win rates are ordinary.

| Upgrade | Offer rate | Pick rate | Pick when offered | Win rate if owned | Mean combats | Mean end HP | Runs |
|---|---:|---:|---:|---:|---:|---:|---:|
| `ember_capacity` | 11.7% | 0.49 | 74.8% | 72.3% | 5.91 | 47.2% | 983 |
| `ash_reserves` | 15.1% | 0.57 | 67.8% | 72.8% | 5.97 | 48.1% | 887 |
| `soul_cache` | 14.5% | 0.49 | 60.4% | 67.2% | 5.81 | 43.3% | 800 |
| `cinder_corpse` | 16.2% | 0.28 | 30.5% | 67.1% | 5.90 | 41.0% | 423 |
| `brute_summons` | 16.0% | 0.27 | 29.8% | 81.9% | 6.13 | 52.1% | 432 |
| `soul_interest` | 15.3% | 0.25 | 29.6% | 67.7% | 5.85 | 41.9% | 405 |
| `chorus_of_ash` | 15.4% | 0.25 | 29.3% | 69.0% | 5.87 | 42.5% | 422 |
| `ember_step` | 16.0% | 0.26 | 29.2% | 73.0% | 5.94 | 46.7% | 441 |
| `bone_ranks` | 15.9% | 0.25 | 28.4% | 81.9% | 6.22 | 52.8% | 414 |
| `rattling_volley` | 16.1% | 0.26 | 28.4% | 70.0% | 5.82 | 44.3% | 423 |
| `break_intent` | 15.3% | 0.24 | 28.4% | 78.1% | 6.08 | 51.3% | 416 |
| `unfinished_rite` | 13.5% | 0.21 | 27.9% | 69.2% | 5.83 | 42.6% | 422 |
| `pyre_funeral` | 15.5% | 0.24 | 27.4% | 70.9% | 5.90 | 43.7% | 392 |
| `grave_call` | 15.8% | 0.24 | 27.3% | 79.0% | 6.10 | 48.8% | 395 |
| `tithe_blade` | 15.7% | 0.24 | 27.2% | 68.7% | 5.92 | 43.5% | 393 |
| `crushing_swing` | 15.4% | 0.23 | 27.1% | 75.3% | 6.05 | 46.2% | 388 |
| `interpose` | 14.5% | 0.22 | 26.8% | 70.4% | 5.80 | 46.0% | 436 |
| `chain_ash` | 13.8% | 0.20 | 26.0% | 69.6% | 5.90 | 43.2% | 401 |
| `last_ember` | 14.4% | 0.21 | 25.9% | 73.7% | 6.00 | 44.6% | 419 |
| `hold_the_line` | 14.0% | 0.19 | 24.5% | 71.3% | 5.85 | 46.4% | 383 |

### Smart (n = 2000, 11574 offers)

| Upgrade | Offer rate | Pick rate | Pick when offered | Win rate if owned | Mean combats | Mean end HP | Runs |
|---|---:|---:|---:|---:|---:|---:|---:|
| `grave_call` | 14.8% | 0.66 | 77.3% | 77.2% | 6.00 | 47.9% | 923 |
| `ember_step` | 15.3% | 0.48 | 54.4% | 77.4% | 5.88 | 48.8% | 699 |
| `hold_the_line` | 12.5% | 0.37 | 51.2% | 72.4% | 5.87 | 43.4% | 742 |
| `break_intent` | 15.6% | 0.42 | 46.9% | 86.8% | 6.15 | 55.5% | 637 |
| `bone_ranks` | 15.1% | 0.39 | 44.7% | 87.0% | 6.19 | 54.5% | 585 |
| `last_ember` | 12.9% | 0.33 | 44.6% | 75.3% | 5.99 | 42.4% | 665 |
| `brute_summons` | 15.3% | 0.33 | 37.2% | 85.0% | 6.12 | 54.9% | 532 |
| `ash_reserves` | 15.4% | 0.29 | 32.2% | 73.6% | 5.99 | 42.7% | 492 |
| `ember_capacity` | 12.6% | 0.23 | 31.7% | 79.2% | 6.03 | 51.6% | 462 |
| `chorus_of_ash` | 16.6% | 0.31 | 31.7% | 75.5% | 6.03 | 47.3% | 465 |
| `soul_cache` | 15.1% | 0.28 | 31.7% | 78.6% | 6.05 | 49.2% | 473 |
| `interpose` | 14.3% | 0.24 | 28.8% | 82.4% | 6.05 | 55.3% | 477 |
| `cinder_corpse` | 15.7% | 0.26 | 28.2% | 68.4% | 5.71 | 41.8% | 339 |
| `tithe_blade` | 15.7% | 0.23 | 25.6% | 71.8% | 5.94 | 43.0% | 354 |
| `rattling_volley` | 15.5% | 0.23 | 25.2% | 86.3% | 6.22 | 53.6% | 336 |
| `unfinished_rite` | 15.6% | 0.17 | 18.7% | 76.9% | 6.07 | 46.0% | 338 |
| `soul_interest` | 15.8% | 0.15 | 16.9% | 73.0% | 5.98 | 44.0% | 211 |
| `chain_ash` | 14.2% | 0.14 | 16.5% | 76.1% | 6.01 | 48.3% | 272 |
| `pyre_funeral` | 16.3% | 0.14 | 15.4% | 81.2% | 6.11 | 51.3% | 234 |
| `crushing_swing` | 15.5% | 0.14 | 15.1% | 86.9% | 6.22 | 53.3% | 222 |

## Over-picked and under-picked

Random does not over- or under-pick. Use it for power, and use smart for what a synergy-aware policy reaches for.

**Over-picked by the smart policy** (pick-when-offered well above one third, win rate not ahead of the other strong cards by enough to justify the rate):

- **Grave Call (77.3%)**. It is genuinely good on random (80.7% wins versus 65.7% overall), so some of the attention is earned. The heuristic still takes it almost whenever it appears, including runs that never get corpses to spend.
- **Ember Step (54.4%)**. Random owners win 73.6%, only a modest lift. The extra draw is valued more than it returns.
- **Hold the Line (51.2%)**. Smart owners win 72.4%, which is the smart average, not above it. Block retention is the policy's favorite comfort pick.

**Under-picked by the smart policy**, relative to how those runs turn out when the upgrade is actually taken:

- **Crushing Swing (15.1% when offered, 86.9% win rate if owned)**. The heuristic waits for 2-cost attacks already in the deck, so it skips the upgrade on starter decks and only takes it once the deck is already heavy. Random, which does not wait, only sees a 73.3% win rate, so this is a conditional card rather than a secret universal best.
- **Rattling Volley (25.2%, 86.3% if owned)** and **Pyre Funeral (15.4%, 81.2% if owned)**. Both are payoff cards. The policy underrates them until the enabler is already installed. On random, Volley alone is only 72.9%; the spike is the pair with Bone Ranks.
- **Chain Ash (16.5%)** and **Soul Interest (16.9%)**. Near the random average when owned. Fine as role cards, easy for the heuristic to pass.
- **Cinder Corpse** is not rare in the smart list (28.2%), and it is the weakest random owner at 67.8%. Explosion trades a corpse you could have Raised for a modest opening hit. That trade is usually worse than keeping the corpse.

**Strongest individual rewards on random**, where pick bias cannot inflate them: Brute Summons (83.0%), Bone Ranks (81.7%), Grave Call (80.7%), Break Intent (77.3%), Last Ember (76.8%). Soul Cache, Chorus of Ash, Unfinished Rite, and Cinder Corpse sit within about four points of the 65.7% baseline.

## Combinations

Pair and triple win rates are subset rates: a run counts if it owns at least those upgrades, whatever else it also holds. Long runs own more upgrades and win more often, so the baseline is every run that owns at least 2 upgrades (pairs) or at least 3 (triples), not the raw 65.7%.

Minimum sample: 60 runs for pairs, 35 for triples.

### Strongest pairs

Random, baseline 65.8%:

| Pair | Win rate | Lift | Runs | Mean end HP |
|---|---:|---:|---:|---:|
| Bone Ranks + Rattling Volley | 96.3% | +30.5 | 135 | 57.7% |
| Grave Call + Rattling Volley | 95.0% | +29.2 | 119 | 55.2% |
| Brute Summons + Soul Cache | 92.5% | +26.7 | 106 | 55.9% |
| Grave Call + Last Ember | 91.2% | +25.4 | 113 | 48.4% |
| Ash Reserves + Brute Summons | 90.7% | +24.9 | 108 | 52.9% |
| Brute Summons + Interpose | 90.7% | +24.9 | 118 | 64.2% |
| Bone Ranks + Grave Call | 90.6% | +24.8 | 138 | 58.4% |
| Bone Ranks + Brute Summons | 90.6% | +24.8 | 127 | 56.2% |

Smart, baseline 72.7%, shows the same families: Break Intent + Interpose (94.8%, n=115), Bone Ranks + Brute Summons (93.9%, n=115), Brute Summons + Soul Cache (93.8%, n=113).

### Strongest triples

Random, baseline 70.6%. Several hit 97–100% but the samples are 35–39 runs, so treat the exact 100% as a small-sample ceiling rather than a proven lock:

- Bone Ranks + Interpose + Pyre Funeral, 100%, n=37
- Bone Ranks + Break Intent + Grave Call, 100%, n=35
- Bone Ranks + Grave Call + Last Ember, 97.4%, n=39
- Bone Ranks + Break Intent + Rattling Volley, 97.1%, n=35

Smart triples with more runs: Bone Ranks + Grave Call + Interpose, 100%, n=79. That is the clearest three-upgrade spike, and it is a real synergy (bodies, more bodies, and those bodies take the hit) rather than one upgrade appearing in every winning pile.

### Weakest pairs

Random's floor is Cinder Corpse + Pyre Funeral at 65.3% (n=124), essentially the pair baseline. Smart's floor is Hold the Line + Tithe Blade at 65.6% (n=125) and Cinder Corpse + Hold the Line at 69.3% (n=101). Explosion-plus-survival does not protect a run that is not killing fast enough, and spending corpses on pyre denies the Raise line that is actually winning.

### Is anything obviously dominant?

Not after the tuning pass. Before it, Ember Capacity was. The shipped field has a best *family* — Skeletons and Brutes, especially Volley, Grave Call, and Interpose — and several other lines (Break Intent, Last Ember, a single Brute) that also clear 75–83% alone. Greedy theme-forcing does not beat random, which is the check that no one theme is mandatory. Bone Ranks + Rattling Volley at 96% is the pair to watch. It is the intended skeleton payoff, it needs both pieces, and it is not a single reward you are handed every fight.

## Tuning

Pre-tune simulation, same 2000 × 3 policies, before any number changes:

| | Random | Greedy | Smart |
|---|---:|---:|---:|
| Win rate before | 71.8% | 74.3% | 82.1% |
| Win rate after | 65.7% | 63.7% | 72.5% |

What was wrong: Ember Capacity granted +1 maximum Energy per stack, up to +2 every turn. On random, owners won **91.2%** against a 71.8% field. Brute Summons + Ember Capacity won **99.1%** (n=117). Bone Ranks + Ember Capacity won **96.2%** (n=157). Almost every top pair contained Capacity. Skeletons also attacked for 3 base plus 2 per Bone Ranks stack, and Brutes for 8 base plus 3 per stack, so the bodies were attacking like extra cards every turn.

First adjustment (Capacity made unique but still +1 Energy every turn, skeleton and brute attacks reduced, Cinder splash/pyre raised) was not enough. Capacity owners still won 89.7% on random. The first point of Energy was the whole problem.

Shipped changes:

- Ember Capacity is unique and only adds Energy on turn 1. Random owners now win **72.3%** (field 65.7%). It no longer sits inside every top pair.
- Skeleton base attack 3 → 2, Bone Ranks attack per stack 2 → 1.
- Brute base attack 8 → 6, Brute Summons attack per stack 3 → 2.
- Cinder Corpse splash 4 → 5, pyre 4 → 6, pyre cap 18 → 16.
- Pyre Funeral damage 5 → 6.
- Chain Ash always primes 3 Burn for the next fight, and explosions apply 3 Burn, so the unique is no longer blank without another explosion upgrade.

Cinder Corpse is still the weakest random owner. A second buff would start to delete the Act 2 rat through opening pyre, so it was left as the low end of the pool.

## Simulator limitations

The fight logic is the real `CombatSession`: the same card data, enemy actions, relics, burn, and upgrade hooks the combat UI calls. It is not a separate damage formula.

What it does not model:

- The player is a greedy bot. It blocks against the intent it can see, takes lethal, and likes temporary Strength when other attacks are still in hand. It does not set up multi-turn lines, and it always focuses the lowest-HP enemy.
- Most encounters are one enemy. Only Act 2 floor 1 is a pair, so in-combat splash is rare. Detonation is judged mostly on the next fight's pyre.
- Card rewards are not a human draft. Every policy takes the first offered card until the deck has 15 cards, and the first boss relic. The shop buys the cheapest card when gold allows and the deck is under 15. It does not buy relics or remove cards.
- Rest heals 25%, the shrine heals 40% and grants a relic, the forge grants +4 Max HP, and the observatory grants its 18 gold. Those match the screens. The sim does not click the UI.
- Pathing rests below 45% HP, avoids elites below 62% HP, and otherwise takes the first listed room.
- Combo win rates share survivorship. The baselines above are the correction used in this report. A 100% triple with n under 40 is a lead, not a conclusion.
