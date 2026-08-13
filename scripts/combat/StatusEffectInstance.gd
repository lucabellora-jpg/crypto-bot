extends RefCounted
class_name StatusEffectInstance

## Runtime instance of a StatusEffectData applied to a CombatUnit.

var data: StatusEffectData
var turns_remaining: int
var stacks: int


func _init(effect_data: StatusEffectData) -> void:
	data = effect_data
	turns_remaining = effect_data.duration_turns
	stacks = effect_data.stacks
