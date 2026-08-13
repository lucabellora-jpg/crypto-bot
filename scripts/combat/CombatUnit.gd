extends RefCounted
class_name CombatUnit

## Runtime combat state wrapping a CharacterData/EnemyData/BossData resource.
## Kept as plain logic (no scene tree) so CombatManager stays UI-agnostic;
## a view node in the combat scene listens to CombatBus to render this.

var source_data: Resource
var is_player: bool
var display_name: String

var max_hp: int
var hp: int
var base_attack: int
var base_defense: int
var speed: int

var domain_gauge: int = 0
var domain_gauge_max: int = 100

var statuses: Array[StatusEffectInstance] = []
var alive: bool = true

var current_phase_index: int = -1 ## only meaningful when source_data is BossData


func _init(data: Resource, is_player_unit: bool) -> void:
	source_data = data
	is_player = is_player_unit
	display_name = data.display_name
	max_hp = data.max_hp
	hp = max_hp
	base_attack = data.attack
	base_defense = data.defense
	speed = data.speed
	domain_gauge_max = data.domain_gauge_max if "domain_gauge_max" in data else 100
	if data is BossData and not data.phases.is_empty():
		current_phase_index = 0


func get_attack() -> int:
	var value := float(base_attack)
	for inst in statuses:
		if inst.data.kind == StatusEffectData.Kind.WEAKEN:
			value *= 1.0 - inst.data.magnitude
		elif inst.data.kind == StatusEffectData.Kind.EMPOWER:
			value *= 1.0 + inst.data.magnitude
	if source_data is BossData:
		var phase := _current_phase()
		if phase != null:
			value *= phase.attack_multiplier
	return int(round(value))


func get_defense() -> int:
	var value := float(base_defense)
	for inst in statuses:
		if inst.data.kind == StatusEffectData.Kind.GUARD:
			value *= 1.0 + inst.data.magnitude
	if source_data is BossData:
		var phase := _current_phase()
		if phase != null:
			value *= phase.defense_multiplier
	return int(round(value))


func _current_phase() -> BossPhaseData:
	var boss := source_data as BossData
	if boss == null or current_phase_index < 0 or current_phase_index >= boss.phases.size():
		return null
	return boss.phases[current_phase_index]


func is_bound() -> bool:
	for inst in statuses:
		if inst.data.kind == StatusEffectData.Kind.BIND:
			return true
	return false


func take_damage(amount: int) -> int:
	var dealt := max(amount, 0)
	hp = max(hp - dealt, 0)
	if hp == 0:
		alive = false
	return dealt


func heal(amount: int) -> int:
	var healed := min(amount, max_hp - hp)
	hp += healed
	return healed


func add_gauge(amount: int) -> void:
	domain_gauge = clampi(domain_gauge + amount, 0, domain_gauge_max)


func is_gauge_full() -> bool:
	return domain_gauge >= domain_gauge_max


func can_use_domain_expansion() -> bool:
	if not (source_data is CharacterData):
		return false
	var char_data := source_data as CharacterData
	return char_data.domain_expansion != null and is_gauge_full()


func add_status(effect: StatusEffectData) -> StatusEffectInstance:
	for inst in statuses:
		if inst.data.kind == effect.kind:
			inst.turns_remaining = max(inst.turns_remaining, effect.duration_turns)
			inst.stacks += effect.stacks
			return inst
	var new_inst := StatusEffectInstance.new(effect)
	statuses.append(new_inst)
	return new_inst


## Applies burn damage and expires statuses. Returns list of [status, damage] pairs for burns ticked.
func tick_statuses() -> Array:
	var ticked: Array = []
	for inst in statuses.duplicate():
		if inst.data.kind == StatusEffectData.Kind.BURN:
			var dmg := int(round(inst.data.magnitude * inst.stacks))
			take_damage(dmg)
			ticked.append([inst, dmg])
		inst.turns_remaining -= 1
		if inst.turns_remaining <= 0:
			statuses.erase(inst)
	return ticked


## Full skill pool (player techniques + domain expansion, or the active boss
## phase's pool, or the flat pool for a regular EnemyData) ignoring gauge gating.
func get_available_skills() -> Array[SkillData]:
	if source_data is CharacterData:
		var char_data := source_data as CharacterData
		var pool: Array[SkillData] = []
		if char_data.basic_attack != null:
			pool.append(char_data.basic_attack)
		pool.append_array(char_data.techniques)
		if char_data.domain_expansion != null:
			pool.append(char_data.domain_expansion)
		return pool
	if source_data is BossData:
		var phase := _current_phase()
		return phase.skills if phase != null else []
	if source_data is EnemyData:
		return (source_data as EnemyData).skills
	return []


func get_skill_weights() -> Array[float]:
	if source_data is BossData:
		var phase := _current_phase()
		return phase.skill_weights if phase != null else []
	if source_data is EnemyData:
		return (source_data as EnemyData).skill_weights
	return []


## Skills actually pickable right now: strips is_domain_expansion entries
## unless the gauge is full. weights (if provided) stay index-aligned.
func get_usable_skills() -> Array[SkillData]:
	var out: Array[SkillData] = []
	for skill in get_available_skills():
		if skill.is_domain_expansion and not is_gauge_full():
			continue
		out.append(skill)
	return out


func get_usable_skill_weights() -> Array[float]:
	var skills := get_available_skills()
	var weights := get_skill_weights()
	if weights.size() != skills.size():
		return []
	var out: Array[float] = []
	for i in skills.size():
		if skills[i].is_domain_expansion and not is_gauge_full():
			continue
		out.append(weights[i])
	return out


## Advances to the next boss phase whose hp_threshold is at/above current hp ratio.
## Returns the new phase if a transition happened, else null.
func check_phase_transition() -> BossPhaseData:
	var boss := source_data as BossData
	if boss == null or current_phase_index < 0:
		return null
	var hp_ratio := float(hp) / float(max_hp)
	var next_index := current_phase_index
	for i in range(current_phase_index + 1, boss.phases.size()):
		if hp_ratio <= boss.phases[i].hp_threshold:
			next_index = i
	if next_index != current_phase_index:
		current_phase_index = next_index
		var phase := boss.phases[next_index]
		if phase.grants_status_self != null:
			add_status(phase.grants_status_self)
		return phase
	return null
