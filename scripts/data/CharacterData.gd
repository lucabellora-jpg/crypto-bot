extends Resource
class_name CharacterData

## A playable sorcerer definition (placeholder dev names — swap before publishing).

enum Grade { GRADE_4, GRADE_3, GRADE_2, GRADE_1, SPECIAL_GRADE }

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var flavor_text: String = ""
@export var grade: Grade = Grade.GRADE_3
@export var portrait: Texture2D = null

@export_group("Base Stats")
@export var max_hp: int = 100
@export var attack: int = 10
@export var defense: int = 5
@export var speed: int = 10

@export_group("Techniques")
@export var basic_attack: SkillData = null
@export var techniques: Array[SkillData] = [] ## 1-3 active cursed techniques
@export var domain_expansion: SkillData = null ## ultimate, nullable if character has none yet
@export var domain_gauge_max: int = 100

@export_group("Meta")
@export var unlock_cost: int = 0 ## meta-currency cost to unlock for runs, 0 = starter
