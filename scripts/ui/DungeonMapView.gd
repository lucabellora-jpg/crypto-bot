extends Control

const NODE_TYPE_LABELS := {
	DungeonNode.Type.COMBAT: "Curse",
	DungeonNode.Type.ELITE: "Elite Curse",
	DungeonNode.Type.EVENT: "Event",
	DungeonNode.Type.SHOP: "Shop",
	DungeonNode.Type.REST: "Rest",
	DungeonNode.Type.BOSS: "Special Grade",
}

var _rows_container: VBoxContainer
var _status_label: Label
var _party_label: Label
var _relics_label: Label


func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	margin.add_child(outer)

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 24)
	outer.add_child(_status_label)

	_party_label = Label.new()
	outer.add_child(_party_label)

	_relics_label = Label.new()
	_relics_label.modulate = Color(0.85, 0.75, 1.0)
	outer.add_child(_relics_label)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 480)
	outer.add_child(scroll)

	_rows_container = VBoxContainer.new()
	_rows_container.add_theme_constant_override("separation", 8)
	scroll.add_child(_rows_container)

	_refresh()


func _refresh() -> void:
	_status_label.text = "Floor %d   |   Shards: %d" % [RunState.current_floor, RunState.run_shards]

	var party_bits: Array[String] = []
	for id in RunState.party_ids:
		var char_data := GameData.get_character(id)
		if char_data != null:
			party_bits.append("%s %d/%d" % [char_data.display_name, RunState.get_party_hp(id), char_data.max_hp])
	_party_label.text = " | ".join(party_bits)

	if RunState.relics.is_empty():
		_relics_label.text = "Relics: none yet"
	else:
		var relic_names: Array[String] = []
		for id in RunState.relics:
			var relic := GameData.get_relic(id)
			if relic != null:
				relic_names.append(relic.display_name)
		_relics_label.text = "Relics: " + ", ".join(relic_names)

	for child in _rows_container.get_children():
		child.queue_free()

	var reachable_ids := RunState.map.get_reachable_nodes(RunState.current_node_id).map(func(n): return n.id)

	for row_index in RunState.map.row_count:
		var row_box := HBoxContainer.new()
		row_box.add_theme_constant_override("separation", 8)
		_rows_container.add_child(row_box)
		for node in RunState.map.get_row(row_index):
			var button := Button.new()
			button.text = "%s\n(%s)" % [NODE_TYPE_LABELS.get(node.type, "???"), "cleared" if node.visited else "row %d" % row_index]
			button.custom_minimum_size = Vector2(140, 60)
			button.disabled = node.visited or not reachable_ids.has(node.id)
			button.pressed.connect(func(): _on_node_pressed(node))
			row_box.add_child(button)


func _on_node_pressed(node: DungeonNode) -> void:
	node.visited = true
	RunState.current_node_id = node.id
	match node.type:
		DungeonNode.Type.COMBAT, DungeonNode.Type.ELITE:
			RunState.pending_encounter_enemies.assign(node.enemy_ids.map(func(id): return GameData.get_enemy(id)))
			RunState.pending_encounter_boss = null
			get_tree().change_scene_to_file("res://scenes/combat/CombatScene.tscn")
		DungeonNode.Type.BOSS:
			RunState.pending_encounter_boss = GameData.get_boss(node.boss_id)
			RunState.pending_encounter_enemies.clear()
			get_tree().change_scene_to_file("res://scenes/combat/CombatScene.tscn")
		DungeonNode.Type.EVENT:
			_resolve_event()
		DungeonNode.Type.SHOP:
			_resolve_shop()
		DungeonNode.Type.REST:
			_resolve_rest()


func _resolve_event() -> void:
	var reward := RunState.rng.randi_range(5, 15)
	RunState.add_run_shards(reward)
	_show_popup("A faint cursed energy signature lingers here. You absorb it.\n\n+%d shards" % reward)


func _resolve_shop() -> void:
	var cost := 20
	if RunState.spend_run_shards(cost):
		RunState.full_heal_party()
		_show_popup("A traveling exorcist patches up your wounds.\n\n-%d shards, party fully healed." % cost)
	else:
		_show_popup("Not enough shards to pay the exorcist (needs %d)." % cost)


func _resolve_rest() -> void:
	RunState.heal_party(0.4)
	_show_popup("You make camp and let your cursed energy settle.\n\nParty recovers some HP.")


func _show_popup(text: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.dialog_text = text
	add_child(dialog)
	dialog.confirmed.connect(func(): _refresh())
	dialog.canceled.connect(func(): _refresh())
	dialog.popup_centered()
