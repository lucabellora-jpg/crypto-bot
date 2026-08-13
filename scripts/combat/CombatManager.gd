extends Node
class_name CombatManager

## Orchestrates one combat encounter: turn order, skill resolution, AI,
## shared party energy, domain-gauge charging and boss phase transitions.
## UI-agnostic — everything it does is broadcast via CombatBus.

const STARTING_ENERGY := 3
const MAX_ENERGY := 10
const ENERGY_PER_ROUND := 2
const CRIT_CHANCE := 0.1
const CRIT_MULTIPLIER := 1.5
const GAUGE_ON_HIT_TAKEN := 8 ## gauge gained when a unit is damaged

var party: Array[CombatUnit] = []
var enemies: Array[CombatUnit] = []
var party_energy: int = STARTING_ENERGY
var party_energy_max: int = MAX_ENERGY
var round_number: int = 0
var rng := RandomNumberGenerator.new()

var _waiting_for_player: bool = false
var _pending_skill: SkillData = null
var _pending_targets: Array[CombatUnit] = []


func setup(party_data: Array[CharacterData], enemy_data: Array[Resource], seed_value: int = -1, starting_hp: Dictionary = {}) -> void:
	rng.seed = seed_value if seed_value >= 0 else randi()
	party = party_data.map(func(d):
		var unit := CombatUnit.new(d, true)
		if starting_hp.has(d.id):
			unit.hp = clampi(starting_hp[d.id], 0, unit.max_hp)
			unit.alive = unit.hp > 0
		return unit
	)
	enemies = enemy_data.map(func(d): return CombatUnit.new(d, false))
	party_energy = STARTING_ENERGY
	round_number = 0


func start_combat() -> void:
	CombatBus.combat_started.emit(party, enemies)
	while _party_alive() and _enemies_alive():
		await _run_round()
	var victory := _party_alive()
	var rewards := _compute_rewards() if victory else {}
	if victory:
		RunState.add_run_shards(rewards.get("shards", 0))
	CombatBus.combat_ended.emit(victory, rewards)


func submit_player_action(skill: SkillData, targets: Array[CombatUnit]) -> void:
	if not _waiting_for_player:
		return
	_pending_skill = skill
	_pending_targets = targets
	_waiting_for_player = false


func _run_round() -> void:
	round_number += 1
	party_energy = min(party_energy + ENERGY_PER_ROUND, party_energy_max)
	CombatBus.round_started.emit(round_number)

	var turn_order := _build_turn_order()
	for unit in turn_order:
		if not unit.alive:
			continue
		if not _party_alive() or not _enemies_alive():
			return
		await _take_turn(unit)


func _build_turn_order() -> Array[CombatUnit]:
	var all_units: Array[CombatUnit] = []
	all_units.append_array(party.filter(func(u): return u.alive))
	all_units.append_array(enemies.filter(func(u): return u.alive))
	all_units.sort_custom(func(a, b): return a.speed > b.speed)
	return all_units


func _take_turn(unit: CombatUnit) -> void:
	CombatBus.turn_started.emit(unit)

	# snapshot bind status before tick_statuses() decrements/expires it, so a
	# 1-turn bind still blocks the very turn it was meant to block
	var was_bound := unit.is_bound()

	var ticked := unit.tick_statuses()
	for pair in ticked:
		CombatBus.status_ticked.emit(unit, pair[0].data, pair[1])
	if not unit.alive:
		CombatBus.unit_defeated.emit(unit)
		return

	if was_bound:
		CombatBus.turn_skipped.emit(unit, "bound")
		return # skip action entirely; bind duration already consumed above

	var skill: SkillData = null
	var targets: Array[CombatUnit] = []

	if unit.is_player:
		var usable := unit.get_usable_skills()
		if usable.is_empty():
			CombatBus.turn_skipped.emit(unit, "no_skills")
			return
		_pending_skill = null
		_pending_targets = []
		_waiting_for_player = true
		CombatBus.action_required.emit(unit)
		while _waiting_for_player:
			await get_tree().process_frame
		skill = _pending_skill
		targets = _pending_targets
		if skill == null or party_energy < skill.energy_cost:
			return
		party_energy -= skill.energy_cost
	else:
		skill = _choose_ai_skill(unit)
		if skill == null:
			return
		targets = _choose_ai_targets(unit, skill)

	await _resolve_action(unit, skill, targets)


func _resolve_action(actor: CombatUnit, skill: SkillData, targets: Array[CombatUnit]) -> void:
	CombatBus.action_selected.emit(actor, skill, targets)
	if skill.is_domain_expansion:
		CombatBus.domain_expansion_triggered.emit(actor, skill)
		actor.domain_gauge = 0
	else:
		actor.add_gauge(skill.gauge_gain_self)
		CombatBus.gauge_changed.emit(actor, actor.domain_gauge, actor.domain_gauge_max)

	for target in targets:
		if not target.alive:
			continue
		var hit := rng.randf() <= skill.accuracy
		if not hit:
			continue
		match skill.effect_type:
			SkillData.EffectType.DAMAGE:
				_apply_damage(actor, target, skill)
			SkillData.EffectType.HEAL:
				_apply_heal(actor, target, skill)
			SkillData.EffectType.BUFF, SkillData.EffectType.DEBUFF:
				_apply_status(target, skill)
			SkillData.EffectType.GAUGE_BONUS:
				target.add_gauge(int(skill.power))
				CombatBus.gauge_changed.emit(target, target.domain_gauge, target.domain_gauge_max)

		if target.source_data is BossData:
			var phase := target.check_phase_transition()
			if phase != null:
				CombatBus.boss_phase_changed.emit(target, phase)

		if not target.alive:
			CombatBus.unit_defeated.emit(target)


func _apply_damage(actor: CombatUnit, target: CombatUnit, skill: SkillData) -> void:
	var is_crit := rng.randf() <= CRIT_CHANCE
	var raw := actor.get_attack() * skill.power - target.get_defense() * 0.5
	raw = max(raw, 1.0)
	if is_crit:
		raw *= CRIT_MULTIPLIER
	var dealt := target.take_damage(int(round(raw)))
	CombatBus.damage_dealt.emit(actor, target, dealt, is_crit)
	target.add_gauge(GAUGE_ON_HIT_TAKEN)
	CombatBus.gauge_changed.emit(target, target.domain_gauge, target.domain_gauge_max)
	if skill.applies_status != null and rng.randf() <= skill.apply_status_chance:
		_apply_status(target, skill)


func _apply_heal(actor: CombatUnit, target: CombatUnit, skill: SkillData) -> void:
	var amount := int(round(actor.get_attack() * skill.power))
	var healed := target.heal(amount)
	CombatBus.healing_done.emit(actor, target, healed)


func _apply_status(target: CombatUnit, skill: SkillData) -> void:
	if skill.applies_status == null:
		return
	target.add_status(skill.applies_status)
	CombatBus.status_applied.emit(target, skill.applies_status)


func _choose_ai_skill(unit: CombatUnit) -> SkillData:
	var skills := unit.get_usable_skills()
	var weights := unit.get_usable_skill_weights()
	if skills.is_empty():
		return null
	if weights.is_empty() or weights.size() != skills.size():
		return skills[rng.randi_range(0, skills.size() - 1)]
	var total := 0.0
	for w in weights:
		total += w
	var roll := rng.randf() * total
	var acc := 0.0
	for i in skills.size():
		acc += weights[i]
		if roll <= acc:
			return skills[i]
	return skills.back()


func _choose_ai_targets(unit: CombatUnit, skill: SkillData) -> Array[CombatUnit]:
	var alive_party := party.filter(func(u): return u.alive)
	var alive_enemies := enemies.filter(func(u): return u.alive)
	match skill.target_type:
		SkillData.TargetType.ENEMY_SINGLE:
			return [alive_party[rng.randi_range(0, alive_party.size() - 1)]] if not alive_party.is_empty() else []
		SkillData.TargetType.ENEMY_ALL:
			return alive_party
		SkillData.TargetType.ALLY_SINGLE:
			return [alive_enemies[rng.randi_range(0, alive_enemies.size() - 1)]] if not alive_enemies.is_empty() else []
		SkillData.TargetType.ALLY_ALL:
			return alive_enemies
		SkillData.TargetType.SELF:
			return [unit]
	return []


func _party_alive() -> bool:
	return party.any(func(u): return u.alive)


func _enemies_alive() -> bool:
	return enemies.any(func(u): return u.alive)


func _compute_rewards() -> Dictionary:
	var shards := 0
	var relic_dropped := false
	for unit in enemies:
		var data := unit.source_data
		if data is EnemyData:
			var e := data as EnemyData
			shards += rng.randi_range(e.shard_reward_min, e.shard_reward_max)
			if rng.randf() <= e.relic_drop_chance:
				relic_dropped = true
	return {"shards": shards, "relic": relic_dropped}
