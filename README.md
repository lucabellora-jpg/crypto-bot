# Cursed Descent

A turn-based roguelike prototype built in Godot 4, using the actual Jujutsu
Kaisen cast, techniques and domains — Gojo, Sukuna, Mahito and the rest —
laid over an original combat/dungeon system (shared cursed-energy pool,
chargeable ultimates, multi-phase boss fights, relics, floor scaling).

> **This uses real Jujutsu Kaisen IP (names, techniques, domain names,
> characters) at the project owner's explicit request, for personal,
> non-published use only.** It is not intended for distribution. If that
> ever changes, everything identity-related lives in `resources/` as data
> and can be swapped without touching any code — see git history for the
> original all-original-IP version this was built from.
>
> Dialogue/flavor text throughout is original writing consistent with each
> character, not transcribed manga text — nothing here is a verbatim
> reproduction of Gege Akutami's actual prose.

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
                    BossPhaseData, SkillData, StatusEffectData, RelicData
  combat/           CombatUnit (runtime unit state), CombatManager
                    (turn order, skill resolution, AI), StatusEffectInstance
  dungeon/          DungeonNode, DungeonMap, DungeonMapGenerator
                    (Slay-the-Spire-style branching node map + floor names)
  ui/               MainMenu, DungeonMapView, CombatSceneView — all UI is
                    built in code (no hand-authored .tscn layouts) so it's
                    easy to read and tweak without the editor
resources/
  statuses/         Burn, Bind, Weaken, Empower, Guard status effects
  skills/           Every technique, basic attack and ultimate
  characters/       6 playable sorcerers (4 starters + 2 unlockable)
  enemies/          7 curses (3 special-grade elites: Eso, Kechizu, Hanami)
  bosses/           Sukuna, Mahito, Jogo — 2-phase fights each
  relics/           6 passive run modifiers, all real cursed tools/items
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
2. **Dungeon Map** — each floor is a real location (Tokyo Jujutsu High,
   Kyoto Jujutsu High, Shibuya, Sendai Colony, Shinjuku, Yasohachi Bridge,
   cycling as floors go up) with a branching node map: curse fights, an
   elite fight, an event, a shop, a rest node, and a special-grade boss at
   the end. Party HP persists between fights within a run (classic
   roguelike tension); it resets to full each new run.
3. **Combat** — turn-based, initiative by Speed. The party shares one
   cursed-energy pool that regenerates each round; each sorcerer's basic
   attack always costs 0 energy so a turn is never a dead end. Landing hits
   and taking hits charges a personal gauge; at 100% a character can
   unleash their strongest technique (a real Domain Expansion for those who
   canonically have one — Megumi, Gojo — and a powered-up signature move
   for those who don't, like Nobara or Yuji).
4. **Bosses** are `BossData` resources with an ordered list of
   `BossPhaseData` — each phase swaps in a new skill pool and stat
   multipliers once the boss's HP drops below that phase's threshold, and
   can grant the boss a self-buff on the transition. Enemies (including
   bosses) also scale up ~10% in HP/attack/defense per floor beyond the
   first, so later runs stay tense instead of flatlining in difficulty.
5. **Relics** — beating a boss or a lucky regular fight can drop a relic
   (`RelicData`): a passive, run-long modifier. Effects from every relic
   owned stack additively and are applied automatically by `CombatManager`
   at the start of each fight.
6. Losing a run empties it (permadeath) but converts leftover run-currency
   into permanent shards for unlocking new sorcerers next time.

## Current roster

| Sorcerer | Role | Grade | Signature moves | Unlock |
|---|---|---|---|---|
| Yuji Itadori | brawler | Grade 4 | Black Flash, Divergent Fist | starter |
| Megumi Fushiguro | shikigami handler | Grade 2 | Nue, Divine Dogs, **Domain: Chimera Shadow Garden** | starter |
| Nobara Kugisaki | straw doll technique | Grade 3 | Resonance, Hairpin | starter |
| Shoko Ieiri | healer/support | Special Grade | Reverse Cursed Technique | starter |
| Maki Zenin | cursed-tool speedster | Grade 1 | Playful Cloud, Heavenly Restriction | 90 shards |
| Gojo Satoru | limitless barrier user | Special Grade | Infinity, Blue, Hollow Purple, **Domain: Unlimited Void** | 150 shards |

Regular curses are mostly unnamed (Grade 4/3 Curse, Finger Bearer, Cursed
Corpse), matching how the manga treats most rank-and-file threats. The
three elites — **Eso**, **Kechizu**, **Hanami** — and the three bosses —
**Sukuna** (Malevolent Shrine), **Mahito** (Self-Embodiment of Perfection),
**Jogo** (Coffin of the Iron Mountain) — cycle by floor number.

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
