# Cursed Descent

A turn-based roguelike prototype built in Godot 4, inspired by the general
shape of *Jujutsu Kaisen: Phantom Parade* — a shared cursed-energy pool spent
on techniques, a chargeable "Domain Expansion" ultimate per character, and
HP-gated multi-phase boss fights — using **original characters, curses and
domain names**.

> **Placeholder-naming note:** at the user's request during early
> development, the roster leans on Jujutsu-Kaisen-*style* archetypes (a
> shikigami handler, a straw-doll technician, a limitless-barrier user, a
> black-flash brawler) so the mechanics have somewhere concrete to live. All
> names, portraits and domain titles are original — nothing here reuses
> copyrighted JJK character names, art or verbatim technique names — so the
> project is safe to keep developing or eventually publish as-is. If you
> still want a harder rename pass before sharing it further, everything
> content-related lives in `resources/` and can be edited without touching
> any code.

## Requirements

Open with **Godot 4.2+** (project is tagged for 4.3). This environment
doesn't have the Godot editor installed, so none of this has been run or
screenshotted — open `project.godot` locally to playtest.

## Project structure

```
project.godot
scripts/
  autoload/        GameData (content registry), RunState (run + meta save),
                    CombatBus (signal bus decoupling combat logic from UI)
  data/             Resource classes: CharacterData, EnemyData, BossData,
                    BossPhaseData, SkillData, StatusEffectData
  combat/           CombatUnit (runtime unit state), CombatManager
                    (turn order, skill resolution, AI), StatusEffectInstance
  dungeon/          DungeonNode, DungeonMap, DungeonMapGenerator
                    (Slay-the-Spire-style branching node map)
  ui/               MainMenu, DungeonMapView, CombatSceneView — all UI is
                    built in code (no hand-authored .tscn layouts) so it's
                    easy to read and tweak without the editor
resources/
  statuses/         Burn, Bind, Weaken, Empower, Guard status effects
  skills/           Every technique, basic attack and Domain Expansion
  characters/       6 playable sorcerers (4 starters + 2 unlockable)
  enemies/          7 regular curses (3 elite-tier)
  bosses/           3 special-grade curses with 2-phase fights
  relics/           6 passive run modifiers awarded from boss/relic drops
scenes/
  ui/MainMenu.tscn
  dungeon/DungeonMap.tscn
  combat/CombatScene.tscn
```

All gameplay content is data (`.tres` Resource files) — adding a new
sorcerer, curse or boss means adding a `.tres` file to the right folder;
`GameData` autoload-scans those folders on startup, no code changes needed.

## Core loop

1. **Main Menu** — pick 3 sorcerers for the run (unlock more with
   persistent Cursed Energy Shards earned across runs).
2. **Dungeon Map** — a branching node map per floor: regular curse fights,
   elite fights, events, a shop, a rest node, and a special-grade boss at
   the end. Party HP persists between fights within a run (classic
   roguelike tension); it resets to full each new run.
3. **Combat** — turn-based, initiative by Speed. The party shares one
   cursed-energy pool that regenerates each round; each sorcerer's basic
   attack always costs 0 energy so a turn is never a dead end. Landing hits
   and taking hits charges a personal Domain Gauge; at 100% a character can
   unleash their Domain Expansion ultimate.
4. **Bosses** are `BossData` resources with an ordered list of
   `BossPhaseData` — each phase swaps in a new skill pool and stat
   multipliers once the boss's HP drops below that phase's threshold, and
   can grant the boss a self-buff on the transition. Enemies (including
   bosses) also scale up ~10% in HP/attack/defense per floor beyond the
   first, so later runs stay tense instead of flatlining in difficulty.
5. **Relics** — beating a boss or a lucky regular fight can drop a relic
   (`RelicData`): a passive, run-long modifier (bonus energy cap, faster
   Domain Gauge charge, party-wide crit/attack/defense bonuses, or bonus
   shard income). Effects from every relic owned stack additively and are
   applied automatically by `CombatManager` at the start of each fight.
6. Losing a run empties it (permadeath) but converts leftover run-currency
   into permanent shards for unlocking new sorcerers next time.

## Current roster

| Sorcerer | Archetype | Grade | Unlock |
|---|---|---|---|
| Haru Someya | brawler | Grade 2 | starter |
| Itsuki Kurogami | shikigami handler | Grade 2 | starter |
| Kaede Ibarahi | straw-doll technician | Grade 3 | starter |
| Mei Sorano | healer/support | Grade 3 | starter |
| Sora Kanade | dual-blade speedster | Grade 2 | 90 shards |
| Rin Amagase | limitless barrier user | Special Grade | 150 shards |

3 special-grade bosses (`Ryomen no Zanma`, `The Hollow King`, `The Endless
Choir`) cycle by floor number so the same boss doesn't repeat back-to-back
on short runs.

## Known gaps / next steps

- No art, audio or animation — everything renders as plain Godot Controls
  (Labels, Buttons, ProgressBars) built in code.
- `BossData.enrage_turn` is a documented but unwired hook for a future
  "fight is dragging on too long" enrage mechanic.
- Only one map shape/size is defined (`DungeonMapGenerator.ROW_WIDTHS`);
  event nodes are a single flat reward rather than a branching-choice system.
- Not run inside a Godot editor in this environment — do a first pass of
  manual playtesting for balance and typos before treating any numbers as
  final.
