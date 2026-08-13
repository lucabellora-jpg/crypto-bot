extends EnemyData
class_name BossData

## A "Special Grade Curse" — boss encounter with HP-gated phases.

@export_multiline var domain_intro_text: String = "" ## flavor text shown when the boss room is entered
@export var phases: Array[BossPhaseData] = [] ## ordered highest hp_threshold first
@export var enrage_turn: int = -1 ## -1 disables; otherwise turn number the boss enrages (damage buff)
@export var enrage_attack_multiplier: float = 1.5
