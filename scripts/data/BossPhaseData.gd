extends Resource
class_name BossPhaseData

## One phase of a boss fight, triggered when boss HP drops at/below hp_threshold.

@export var hp_threshold: float = 1.0 ## 0..1, fraction of max_hp that triggers this phase
@export var phase_name: String = ""
@export_multiline var intro_text: String = "" ## shown once when phase begins
@export var skills: Array[SkillData] = []
@export var skill_weights: Array[float] = []
@export var attack_multiplier: float = 1.0 ## applied on top of base attack while this phase is active
@export var defense_multiplier: float = 1.0
@export var grants_status_self: StatusEffectData = null ## e.g. self-buff on phase transition
