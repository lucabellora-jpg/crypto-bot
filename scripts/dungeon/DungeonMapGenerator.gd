extends RefCounted
class_name DungeonMapGenerator

## Procedural node-map generator, Slay-the-Spire style: rows of nodes with
## forward-only connections, ending in a single boss node.

const ROW_WIDTHS := [3, 3, 4, 4, 3, 3, 1] ## last row is always the boss

const TYPE_WEIGHTS := {
	DungeonNode.Type.COMBAT: 5.0,
	DungeonNode.Type.EVENT: 2.0,
	DungeonNode.Type.SHOP: 1.0,
	DungeonNode.Type.ELITE: 1.5,
	DungeonNode.Type.REST: 1.5,
}

## Real locations, cycled by floor number so a run reads as a descent
## through the setting rather than an abstract "Floor N".
const FLOOR_NAMES := [
	"Tokyo Jujutsu High",
	"Kyoto Jujutsu High",
	"Shibuya",
	"Sendai Colony",
	"Shinjuku",
	"Yasohachi Bridge",
]


static func floor_name(floor_number: int) -> String:
	return FLOOR_NAMES[(floor_number - 1) % FLOOR_NAMES.size()]


static func generate(rng: RandomNumberGenerator, floor_number: int) -> DungeonMap:
	var map := DungeonMap.new()
	map.floor_number = floor_number
	map.row_count = ROW_WIDTHS.size()

	var rows: Array = []
	var next_id := 0
	for row_index in ROW_WIDTHS.size():
		var width: int = ROW_WIDTHS[row_index]
		var row_nodes: Array[DungeonNode] = []
		for col in width:
			var node := DungeonNode.new()
			node.id = next_id
			next_id += 1
			node.row = row_index
			node.column = col
			node.type = _pick_type(rng, row_index)
			_assign_encounter(node, rng, floor_number)
			row_nodes.append(node)
			map.nodes.append(node)
		rows.append(row_nodes)

	for row_index in ROW_WIDTHS.size() - 1:
		_connect_rows(rows[row_index], rows[row_index + 1], rng)

	return map


static func _pick_type(rng: RandomNumberGenerator, row_index: int) -> DungeonNode.Type:
	if row_index == 0:
		return DungeonNode.Type.COMBAT
	if row_index == ROW_WIDTHS.size() - 1:
		return DungeonNode.Type.BOSS
	if row_index == ROW_WIDTHS.size() - 2:
		return DungeonNode.Type.REST if rng.randf() < 0.6 else DungeonNode.Type.COMBAT

	var total := 0.0
	for w in TYPE_WEIGHTS.values():
		total += w
	var roll := rng.randf() * total
	var acc := 0.0
	for type_key in TYPE_WEIGHTS.keys():
		acc += TYPE_WEIGHTS[type_key]
		if roll <= acc:
			return type_key
	return DungeonNode.Type.COMBAT


static func _assign_encounter(node: DungeonNode, rng: RandomNumberGenerator, floor_number: int) -> void:
	match node.type:
		DungeonNode.Type.COMBAT:
			node.enemy_ids = _random_enemy_ids(rng, rng.randi_range(1, 2), floor_number, false)
		DungeonNode.Type.ELITE:
			node.enemy_ids = _random_enemy_ids(rng, rng.randi_range(2, 3), floor_number, true)
		DungeonNode.Type.BOSS:
			var ids := GameData.bosses.keys()
			if not ids.is_empty():
				node.boss_id = ids[(floor_number - 1) % ids.size()]


static func _random_enemy_ids(rng: RandomNumberGenerator, count: int, _floor_number: int, elite: bool) -> Array[String]:
	var pool: Array[String] = []
	for id in GameData.enemies.keys():
		var e: EnemyData = GameData.enemies[id]
		var is_elite := e.grade >= EnemyData.Grade.GRADE_2
		if elite == is_elite:
			pool.append(id)
	if pool.is_empty():
		pool = GameData.enemies.keys()
	var out: Array[String] = []
	for i in count:
		if pool.is_empty():
			break
		out.append(pool[rng.randi_range(0, pool.size() - 1)])
	return out


static func _connect_rows(current: Array, next: Array, rng: RandomNumberGenerator) -> void:
	var next_width: int = next.size()
	var current_width: int = current.size()
	var covered := {}

	for node in current:
		var target_index := 0
		if current_width > 1 and next_width > 1:
			target_index = int(round(float(node.column) * float(next_width - 1) / float(current_width - 1)))
		var candidates: Array[int] = []
		for delta in [-1, 0, 1]:
			var idx: int = clampi(target_index + delta, 0, next_width - 1)
			if not candidates.has(idx):
				candidates.append(idx)
		var connection_count: int = 1 if next_width == 1 else rng.randi_range(1, min(2, candidates.size()))
		candidates.shuffle()
		for i in connection_count:
			var next_node: DungeonNode = next[candidates[i]]
			(node as DungeonNode).connections.append(next_node.id)
			covered[next_node.id] = true

	# guarantee every node in the next row is reachable from somewhere
	for next_node in next:
		if not covered.has((next_node as DungeonNode).id):
			var closest: DungeonNode = current[clampi((next_node as DungeonNode).column, 0, current_width - 1)]
			closest.connections.append((next_node as DungeonNode).id)
