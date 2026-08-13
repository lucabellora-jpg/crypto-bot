extends Node
## Autoload: current roguelike run state + persistent meta-progression.

signal run_started
signal run_ended(victory: bool)
signal meta_currency_changed(new_total: int)

const SAVE_PATH := "user://save.cfg"

# --- current run ---
var in_run: bool = false
var party_ids: Array[String] = []
var current_floor: int = 1
var map: DungeonMap = null
var current_node_id: int = -1
var run_shards: int = 0 ## in-run currency, lost on run end
var relics: Array[String] = []
var rng := RandomNumberGenerator.new()
var party_hp: Dictionary = {} ## character id -> current hp, persists between fights this run

# --- handoff to CombatScene, set by DungeonMap before changing scenes ---
var pending_encounter_enemies: Array[EnemyData] = []
var pending_encounter_boss: BossData = null

# --- persistent meta progression ---
var meta_shards: int = 0 ## persists across runs, spent on permanent unlocks
var unlocked_character_ids: Array[String] = []
var best_floor_reached: int = 0
var total_runs: int = 0


func _ready() -> void:
	load_meta()


func start_new_run(chosen_party_ids: Array[String], seed_value: int = -1) -> void:
	party_ids = chosen_party_ids.duplicate()
	current_floor = 1
	run_shards = 0
	relics.clear()
	current_node_id = -1
	party_hp.clear()
	for id in party_ids:
		var char_data := GameData.get_character(id)
		party_hp[id] = char_data.max_hp if char_data != null else 0
	rng.seed = seed_value if seed_value >= 0 else randi()
	map = DungeonMapGenerator.generate(rng, current_floor)
	in_run = true
	run_started.emit()


func get_party_hp(id: String) -> int:
	return party_hp.get(id, 0)


func set_party_hp(id: String, value: int) -> void:
	var char_data := GameData.get_character(id)
	var max_hp := char_data.max_hp if char_data != null else value
	party_hp[id] = clampi(value, 0, max_hp)


func heal_party(fraction_of_missing: float) -> void:
	for id in party_ids:
		var char_data := GameData.get_character(id)
		if char_data == null:
			continue
		var missing := char_data.max_hp - get_party_hp(id)
		set_party_hp(id, get_party_hp(id) + int(round(missing * fraction_of_missing)))


func full_heal_party() -> void:
	for id in party_ids:
		var char_data := GameData.get_character(id)
		if char_data != null:
			set_party_hp(id, char_data.max_hp)


func end_run(victory: bool) -> void:
	in_run = false
	total_runs += 1
	best_floor_reached = max(best_floor_reached, current_floor)
	# in-run shards partially convert to permanent currency as a consolation
	var conversion := run_shards if victory else int(run_shards * 0.5)
	add_meta_shards(conversion)
	save_meta()
	run_ended.emit(victory)


func advance_floor() -> void:
	current_floor += 1
	current_node_id = -1
	map = DungeonMapGenerator.generate(rng, current_floor)


func add_run_shards(amount: int) -> void:
	run_shards += amount


func spend_run_shards(amount: int) -> bool:
	if run_shards < amount:
		return false
	run_shards -= amount
	return true


## Sums every owned relic's effect fields into one modifier bundle for
## CombatManager to apply. Adding a relic never requires touching this code.
func get_relic_modifiers() -> Dictionary:
	var mods := {
		"energy_max_bonus": 0,
		"gauge_gain_bonus_pct": 0.0,
		"crit_chance_bonus": 0.0,
		"party_attack_bonus_pct": 0.0,
		"party_defense_bonus_pct": 0.0,
		"shard_gain_bonus_pct": 0.0,
	}
	for id in relics:
		var relic := GameData.get_relic(id)
		if relic == null:
			continue
		mods.energy_max_bonus += relic.energy_max_bonus
		mods.gauge_gain_bonus_pct += relic.gauge_gain_bonus_pct
		mods.crit_chance_bonus += relic.crit_chance_bonus
		mods.party_attack_bonus_pct += relic.party_attack_bonus_pct
		mods.party_defense_bonus_pct += relic.party_defense_bonus_pct
		mods.shard_gain_bonus_pct += relic.shard_gain_bonus_pct
	return mods


## Awards a random relic the party doesn't already own. Returns it, or null
## if every known relic is already owned.
func add_random_relic() -> RelicData:
	var candidates: Array[String] = []
	for id in GameData.relics.keys():
		if not relics.has(id):
			candidates.append(id)
	if candidates.is_empty():
		return null
	var picked: String = candidates[rng.randi_range(0, candidates.size() - 1)]
	relics.append(picked)
	return GameData.get_relic(picked)


func add_meta_shards(amount: int) -> void:
	meta_shards += amount
	meta_currency_changed.emit(meta_shards)


func unlock_character(id: String) -> bool:
	var data := GameData.get_character(id)
	if data == null or id in unlocked_character_ids:
		return false
	if meta_shards < data.unlock_cost:
		return false
	meta_shards -= data.unlock_cost
	unlocked_character_ids.append(id)
	meta_currency_changed.emit(meta_shards)
	save_meta()
	return true


func is_character_available(id: String) -> bool:
	var data := GameData.get_character(id)
	if data == null:
		return false
	return data.unlock_cost <= 0 or id in unlocked_character_ids


func save_meta() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "shards", meta_shards)
	cfg.set_value("meta", "unlocked_characters", unlocked_character_ids)
	cfg.set_value("meta", "best_floor", best_floor_reached)
	cfg.set_value("meta", "total_runs", total_runs)
	cfg.save(SAVE_PATH)


func load_meta() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	meta_shards = cfg.get_value("meta", "shards", 0)
	var loaded_ids = cfg.get_value("meta", "unlocked_characters", [])
	unlocked_character_ids.assign(loaded_ids)
	best_floor_reached = cfg.get_value("meta", "best_floor", 0)
	total_runs = cfg.get_value("meta", "total_runs", 0)
