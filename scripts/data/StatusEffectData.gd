extends Resource
class_name StatusEffectData

enum Kind { BURN, BIND, WEAKEN, EMPOWER, GUARD, REGEN, SEAL }

@export var kind: Kind = Kind.BURN
@export var display_name: String = ""
@export var duration_turns: int = 2
@export var magnitude: float = 0.0 # damage per turn, % stat change, etc.
@export var stacks: int = 1
