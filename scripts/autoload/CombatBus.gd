extends Node
## Autoload: decouples CombatManager logic from combat UI via signals.

signal combat_started(party: Array, enemies: Array)
signal round_started(round_number: int)
signal turn_started(unit: CombatUnit)
signal turn_skipped(unit: CombatUnit, reason: String)
signal action_required(unit: CombatUnit) ## UI must call CombatManager.submit_player_action()
signal action_selected(unit: CombatUnit, skill: SkillData, targets: Array)
signal damage_dealt(source: CombatUnit, target: CombatUnit, amount: int, was_crit: bool)
signal healing_done(source: CombatUnit, target: CombatUnit, amount: int)
signal status_applied(target: CombatUnit, status: StatusEffectData)
signal status_ticked(target: CombatUnit, status: StatusEffectData, damage: int)
signal gauge_changed(unit: CombatUnit, new_value: int, max_value: int)
signal domain_expansion_triggered(unit: CombatUnit, skill: SkillData)
signal unit_defeated(unit: CombatUnit)
signal boss_phase_changed(unit: CombatUnit, phase: BossPhaseData)
signal combat_ended(victory: bool, rewards: Dictionary)
