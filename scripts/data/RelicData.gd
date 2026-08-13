extends Resource
class_name RelicData

## A passive run-modifier collected from boss fights and rare event nodes.
## Effects stack additively across all relics owned this run.

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D = null

@export_group("Effects (all optional, default = no effect)")
@export var energy_max_bonus: int = 0
@export var gauge_gain_bonus_pct: float = 0.0 ## extra domain gauge charge on party skill use
@export var crit_chance_bonus: float = 0.0 ## added to the party's base crit chance
@export var party_attack_bonus_pct: float = 0.0
@export var party_defense_bonus_pct: float = 0.0
@export var shard_gain_bonus_pct: float = 0.0 ## extra shards earned from combat rewards
