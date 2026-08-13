extends Node
## Autoload: central registry of all authored content (.tres resources).
## Scans resources/ subfolders on startup so new content just needs to be
## dropped into the right folder — no manual registration required.

var characters: Dictionary = {} # id -> CharacterData
var enemies: Dictionary = {} # id -> EnemyData
var bosses: Dictionary = {} # id -> BossData
var relics: Dictionary = {} # id -> RelicData

const CHARACTERS_PATH := "res://resources/characters"
const ENEMIES_PATH := "res://resources/enemies"
const BOSSES_PATH := "res://resources/bosses"
const RELICS_PATH := "res://resources/relics"


func _ready() -> void:
	_load_folder(CHARACTERS_PATH, characters)
	_load_folder(ENEMIES_PATH, enemies)
	_load_folder(BOSSES_PATH, bosses)
	_load_folder(RELICS_PATH, relics)
	print("[GameData] loaded %d characters, %d enemies, %d bosses, %d relics" % [
		characters.size(), enemies.size(), bosses.size(), relics.size()
	])


func _load_folder(path: String, into: Dictionary) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		push_warning("[GameData] could not open %s" % path)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var res := load(path + "/" + file_name)
			if res != null and "id" in res and res.id != "":
				into[res.id] = res
			else:
				push_warning("[GameData] resource %s missing an id" % file_name)
		file_name = dir.get_next()
	dir.list_dir_end()


func get_character(id: String) -> CharacterData:
	return characters.get(id, null)


func get_enemy(id: String) -> EnemyData:
	return enemies.get(id, null)


func get_boss(id: String) -> BossData:
	return bosses.get(id, null)


func get_relic(id: String) -> RelicData:
	return relics.get(id, null)


func get_starter_characters() -> Array[CharacterData]:
	var out: Array[CharacterData] = []
	for c: CharacterData in characters.values():
		if c.unlock_cost <= 0:
			out.append(c)
	return out
