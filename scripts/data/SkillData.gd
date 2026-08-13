extends Resource
class_name SkillData

## A "Cursed Technique" — a usable combat skill.

enum TargetType { ENEMY_SINGLE, ENEMY_ALL, ALLY_SINGLE, ALLY_ALL, SELF }
enum EffectType { DAMAGE, HEAL, BUFF, DEBUFF, GAUGE_BONUS }

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""

@export var energy_cost: int = 0 ## shared party cursed-energy pool cost
@export var power: float = 1.0 ## multiplier applied to caster's attack stat
@export var accuracy: float = 1.0 ## 0..1 chance to land

@export var target_type: TargetType = TargetType.ENEMY_SINGLE
@export var effect_type: EffectType = EffectType.DAMAGE

@export var applies_status: StatusEffectData = null
@export var apply_status_chance: float = 1.0

@export var gauge_gain_self: int = 15 ## domain gauge charge earned by the caster on use
@export var is_domain_expansion: bool = false ## true = ultimate, requires full gauge
