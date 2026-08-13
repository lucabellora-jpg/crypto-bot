extends Control

const PARTY_SIZE := 3

var _content: VBoxContainer
var _selected_ids: Array[String] = []
var _shards_label: Label


func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_top", 32)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_bottom", 32)
	add_child(margin)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 20)
	margin.add_child(outer)

	var title := Label.new()
	title.text = "CURSED DESCENT"
	title.add_theme_font_size_override("font_size", 36)
	outer.add_child(title)

	_shards_label = Label.new()
	outer.add_child(_shards_label)
	_refresh_shards_label()
	RunState.meta_currency_changed.connect(func(_v): _refresh_shards_label())

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 10)
	outer.add_child(_content)

	_show_main_view()


func _refresh_shards_label() -> void:
	_shards_label.text = "Cursed Energy Shards: %d   |   Best Floor: %d" % [RunState.meta_shards, RunState.best_floor_reached]


func _clear_content() -> void:
	for child in _content.get_children():
		child.queue_free()


func _show_main_view() -> void:
	_clear_content()
	_content.add_child(_make_button("New Run", _show_party_select))
	_content.add_child(_make_button("Unlock Sorcerers", _show_unlock_view))
	_content.add_child(_make_button("Quit", func(): get_tree().quit()))


func _show_party_select() -> void:
	_clear_content()
	_selected_ids.clear()

	var hint := Label.new()
	hint.text = "Choose %d sorcerers for this run:" % PARTY_SIZE
	_content.add_child(hint)

	var list := VBoxContainer.new()
	_content.add_child(list)

	for char_data: CharacterData in GameData.characters.values():
		if not RunState.is_character_available(char_data.id):
			continue
		var button := Button.new()
		button.toggle_mode = true
		button.text = "%s  (HP %d / ATK %d / SPD %d)" % [char_data.display_name, char_data.max_hp, char_data.attack, char_data.speed]
		button.pressed.connect(func(): _toggle_party_member(char_data.id, button))
		list.add_child(button)

	var start_button := _make_button("Start Run", _start_run)
	start_button.name = "StartRunButton"
	start_button.disabled = true
	_content.add_child(start_button)
	_content.add_child(_make_button("Back", _show_main_view))


func _toggle_party_member(id: String, button: Button) -> void:
	if button.button_pressed:
		if _selected_ids.size() >= PARTY_SIZE:
			button.button_pressed = false
			return
		_selected_ids.append(id)
	else:
		_selected_ids.erase(id)
	var start_button := _content.find_child("StartRunButton", true, false)
	if start_button:
		start_button.disabled = _selected_ids.size() != PARTY_SIZE


func _start_run() -> void:
	RunState.start_new_run(_selected_ids)
	get_tree().change_scene_to_file("res://scenes/dungeon/DungeonMap.tscn")


func _show_unlock_view() -> void:
	_clear_content()
	var any_locked := false
	for char_data: CharacterData in GameData.characters.values():
		if RunState.is_character_available(char_data.id):
			continue
		any_locked = true
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = "%s — cost %d" % [char_data.display_name, char_data.unlock_cost]
		label.custom_minimum_size = Vector2(280, 0)
		row.add_child(label)
		var buy_button := Button.new()
		buy_button.text = "Unlock"
		buy_button.disabled = RunState.meta_shards < char_data.unlock_cost
		buy_button.pressed.connect(func():
			if RunState.unlock_character(char_data.id):
				_show_unlock_view()
		)
		row.add_child(buy_button)
		_content.add_child(row)
	if not any_locked:
		var label := Label.new()
		label.text = "Every sorcerer is already unlocked."
		_content.add_child(label)
	_content.add_child(_make_button("Back", _show_main_view))


func _make_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	return button
