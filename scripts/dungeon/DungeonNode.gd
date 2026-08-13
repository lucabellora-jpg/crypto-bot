extends RefCounted
class_name DungeonNode

enum Type { COMBAT, ELITE, EVENT, SHOP, REST, BOSS }

var id: int = -1
var row: int = 0
var column: int = 0
var type: Type = Type.COMBAT
var connections: Array[int] = [] ## node ids reachable in the next row
var visited: bool = false

## Encounter payload, resolved at generation time so the same node always
## produces the same fight if the player backtracks to view the map.
var enemy_ids: Array[String] = [] ## used when type == COMBAT or ELITE
var boss_id: String = "" ## used when type == BOSS
