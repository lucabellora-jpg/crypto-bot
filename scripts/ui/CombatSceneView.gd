extends Control

var combat_manager: CombatManager

var _party_panel: VBoxContainer
var _enemy_panel: VBoxContainer
var _action_panel: VBoxContainer
var _log: RichTextLabel
var _round_label: Label

var _current_acting_unit: CombatUnit = null


func _ready() -> void:
	_build_ui()
	_connect_bus()
	_start_encounter()


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	margin.add_child(outer)

	_round_label = Label.new()
	_round_label.add_theme_font_size_override("font_size", 22)
	outer.add_child(_round_label)

	var battlefield := HBoxContainer.new()
	battlefield.add_theme_constant_override("separation", 32)
	outer.add_child(battlefield)

	var party_box := VBoxContainer.new()
	party_box.custom_minimum_size = Vector2(360, 0)
	battlefield.add_child(party_box)
	party_box.add_child(_make_header("Sorcerers"))
	_party_panel = VBoxContainer.new()
	_party_panel.add_theme_constant_override("separation", 6)
	party_box.add_child(_party_panel)

	var enemy_box := VBoxContainer.new()
	enemy_box.custom_minimum_size = Vector2(360, 0)
	battlefield.add_child(enemy_box)
	enemy_box.add_child(_make_header("Curses"))
	_enemy_panel = VBoxContainer.new()
	_enemy_panel.add_theme_constant_override("separation", 6)
	enemy_box.add_child(_enemy_panel)

	_action_panel = VBoxContainer.new()
	_action_panel.add_theme_constant_override("separation", 6)
	outer.add_child(_action_panel)

	_log = RichTextLabel.new()
	_log.custom_minimum_size = Vector2(0, 180)
	_log.scroll_following = true
	_log.bbcode_enabled = false
	outer.add_child(_log)


func _make_header(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	return label


func _connect_bus() -> void:
	CombatBus.round_started.connect(func(n): _round_label.text = "Round %d" % n)
	CombatBus.turn_started.connect(func(_u): _clear_action_panel())
	CombatBus.turn_skipped.connect(func(u, reason): _append_log("%s's turn is skipped (%s)." % [u.display_name, reason]))
	CombatBus.action_required.connect(_on_action_required)
	CombatBus.damage_dealt.connect(func(source, target, amount, was_crit):
		_append_log("%s hits %s for %d%s." % [source.display_name, target.display_name, amount, " (CRIT)" if was_crit else ""])
		_refresh_units()
	)
	CombatBus.healing_done.connect(func(source, target, amount):
		_append_log("%s heals %s for %d." % [source.display_name, target.display_name, amount])
		_refresh_units()
	)
	CombatBus.status_applied.connect(func(target, status):
		_append_log("%s is afflicted with %s." % [target.display_name, status.display_name])
		_refresh_units()
	)
	CombatBus.status_ticked.connect(func(target, status, damage):
		if damage > 0:
			_append_log("%s takes %d from %s." % [target.display_name, damage, status.display_name])
		_refresh_units()
	)
	CombatBus.domain_expansion_triggered.connect(func(unit, skill):
		_append_log("*** %s unleashes %s! ***" % [unit.display_name, skill.display_name])
	)
	CombatBus.boss_phase_changed.connect(func(unit, phase):
		_append_log("%s enters phase: %s\n%s" % [unit.display_name, phase.phase_name, phase.intro_text])
		_refresh_units()
	)
	CombatBus.unit_defeated.connect(func(unit):
		_append_log("%s is defeated." % unit.display_name)
		_refresh_units()
	)
	CombatBus.combat_ended.connect(_on_combat_ended)


func _start_encounter() -> void:
	combat_manager = CombatManager.new()
	add_child(combat_manager)

	var party_data: Array[CharacterData] = []
	for id in RunState.party_ids:
		var c := GameData.get_character(id)
		if c != null:
			party_data.append(c)

	var enemy_data: Array[Resource] = []
	if RunState.pending_encounter_boss != null:
		_append_log(RunState.pending_encounter_boss.domain_intro_text)
		enemy_data.append(RunState.pending_encounter_boss)
	else:
		enemy_data.assign(RunState.pending_encounter_enemies)

	combat_manager.setup(party_data, enemy_data, -1, RunState.party_hp)
	_refresh_units()
	combat_manager.start_combat()


func _refresh_units() -> void:
	for child in _party_panel.get_children():
		child.queue_free()
	for child in _enemy_panel.get_children():
		child.queue_free()
	for unit in combat_manager.party:
		_party_panel.add_child(_make_unit_row(unit))
	for unit in combat_manager.enemies:
		_enemy_panel.add_child(_make_unit_row(unit))


func _make_unit_row(unit: CombatUnit) -> Control:
	var box := VBoxContainer.new()

	var name_label := Label.new()
	var status_text := ""
	if not unit.statuses.is_empty():
		var names: Array[String] = []
		for inst in unit.statuses:
			names.append(inst.data.display_name)
		status_text = "  [%s]" % ", ".join(names)
	name_label.text = "%s%s" % [unit.display_name, status_text]
	if not unit.alive:
		name_label.modulate = Color(0.6, 0.6, 0.6)
	box.add_child(name_label)

	var hp_bar := ProgressBar.new()
	hp_bar.max_value = unit.max_hp
	hp_bar.value = unit.hp
	hp_bar.show_percentage = false
	var hp_label := Label.new()
	hp_label.text = "HP %d / %d" % [unit.hp, unit.max_hp]
	box.add_child(hp_bar)
	box.add_child(hp_label)

	var gauge_bar := ProgressBar.new()
	gauge_bar.max_value = unit.domain_gauge_max
	gauge_bar.value = unit.domain_gauge
	gauge_bar.show_percentage = false
	var gauge_label := Label.new()
	gauge_label.text = "Gauge %d / %d" % [unit.domain_gauge, unit.domain_gauge_max]
	box.add_child(gauge_bar)
	box.add_child(gauge_label)

	return box


func _clear_action_panel() -> void:
	for child in _action_panel.get_children():
		child.queue_free()
	_current_acting_unit = null


func _on_action_required(unit: CombatUnit) -> void:
	_current_acting_unit = unit
	_clear_action_panel()

	var prompt := Label.new()
	prompt.text = "%s's turn — energy: %d" % [unit.display_name, combat_manager.party_energy]
	_action_panel.add_child(prompt)

	var skills_row := HBoxContainer.new()
	skills_row.add_theme_constant_override("separation", 6)
	_action_panel.add_child(skills_row)

	for skill: SkillData in unit.get_usable_skills():
		var button := Button.new()
		button.text = "%s (%d)" % [skill.display_name, skill.energy_cost]
		button.disabled = skill.energy_cost > combat_manager.party_energy
		button.pressed.connect(func(): _on_skill_chosen(skill))
		skills_row.add_child(button)


func _on_skill_chosen(skill: SkillData) -> void:
	if _current_acting_unit == null:
		return
	match skill.target_type:
		SkillData.TargetType.ENEMY_SINGLE:
			_show_target_picker(combat_manager.enemies, skill)
		SkillData.TargetType.ALLY_SINGLE:
			_show_target_picker(combat_manager.party, skill)
		SkillData.TargetType.ENEMY_ALL:
			_submit(skill, combat_manager.enemies.filter(func(u): return u.alive))
		SkillData.TargetType.ALLY_ALL:
			_submit(skill, combat_manager.party.filter(func(u): return u.alive))
		SkillData.TargetType.SELF:
			_submit(skill, [_current_acting_unit])


func _show_target_picker(pool: Array[CombatUnit], skill: SkillData) -> void:
	for child in _action_panel.get_children():
		if child.name == "TargetRow":
			child.queue_free()
	var row := HBoxContainer.new()
	row.name = "TargetRow"
	row.add_theme_constant_override("separation", 6)
	_action_panel.add_child(row)
	for unit in pool:
		if not unit.alive:
			continue
		var button := Button.new()
		button.text = "%s (%d hp)" % [unit.display_name, unit.hp]
		button.pressed.connect(func(): _submit(skill, [unit]))
		row.add_child(button)


func _submit(skill: SkillData, targets: Array[CombatUnit]) -> void:
	combat_manager.submit_player_action(skill, targets)
	_clear_action_panel()


func _append_log(text: String) -> void:
	if text == null or text == "":
		return
	_log.append_text(text + "\n")


func _on_combat_ended(victory: bool, rewards: Dictionary) -> void:
	_clear_action_panel()
	if victory:
		for unit in combat_manager.party:
			var char_data := unit.source_data as CharacterData
			var final_hp := unit.hp if unit.alive else max(1, int(unit.max_hp * 0.2))
			RunState.set_party_hp(char_data.id, final_hp)
		var shard_gain: int = rewards.get("shards", 0)
		_append_log("Victory! +%d shards." % shard_gain)
		if rewards.get("relic", false):
			_append_log("A relic was recovered.")
		var was_boss := RunState.pending_encounter_boss != null
		RunState.pending_encounter_enemies.clear()
		RunState.pending_encounter_boss = null
		if was_boss:
			RunState.advance_floor()
		_show_end_dialog("Victory", _build_victory_text(shard_gain, rewards), "res://scenes/dungeon/DungeonMap.tscn")
	else:
		RunState.end_run(false)
		_show_end_dialog("Defeat", "Your party has fallen. The run ends here.", "res://scenes/ui/MainMenu.tscn")


func _build_victory_text(shard_gain: int, rewards: Dictionary) -> String:
	var text := "The fight is won. +%d shards." % shard_gain
	if rewards.get("relic", false):
		text += "\nA relic was recovered."
	return text


func _show_end_dialog(title: String, text: String, next_scene: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = title
	dialog.dialog_text = text
	add_child(dialog)
	dialog.confirmed.connect(func(): get_tree().change_scene_to_file(next_scene))
	dialog.canceled.connect(func(): get_tree().change_scene_to_file(next_scene))
	dialog.popup_centered()
