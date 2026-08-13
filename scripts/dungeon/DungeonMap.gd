extends RefCounted
class_name DungeonMap

var nodes: Array[DungeonNode] = []
var row_count: int = 0
var floor_number: int = 1


func get_node(id: int) -> DungeonNode:
	for n in nodes:
		if n.id == id:
			return n
	return null


func get_row(row: int) -> Array[DungeonNode]:
	return nodes.filter(func(n): return n.row == row)


## Nodes the player may travel to from current_node_id. Passing -1 returns
## the entry row (row 0), i.e. the choices available at the start of the floor.
func get_reachable_nodes(current_node_id: int) -> Array[DungeonNode]:
	if current_node_id == -1:
		return get_row(0)
	var current := get_node(current_node_id)
	if current == null:
		return []
	return current.connections.map(func(id): return get_node(id))


func is_final_node(node_id: int) -> bool:
	var node := get_node(node_id)
	return node != null and node.type == DungeonNode.Type.BOSS
