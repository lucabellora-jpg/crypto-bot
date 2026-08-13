extends Resource
class_name EnemyData

## A "Curse" — regular enemy definition.

enum Grade { GRADE_4, GRADE_3, GRADE_2, GRADE_1, SPECIAL_GRADE }

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var flavor_text: String = ""
@export var grade: Grade = Grade.GRADE_4
@export var portrait: Texture2D = null

@export_group("Base Stats")
@export var max_hp: int = 60
@export var attack: int = 8
@export var defense: int = 3
@export var speed: int = 8

@export_group("Behavior")
@export var skills: Array[SkillData] = [] ## AI picks from this pool
@export var skill_weights: Array[float] = [] ## parallel array to skills, relative pick weight

@export_group("Rewards")
@export var shard_reward_min: int = 5
@export var shard_reward_max: int = 12
@export var relic_drop_chance: float = 0.1
