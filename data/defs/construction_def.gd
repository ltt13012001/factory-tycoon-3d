## A building project: costs money, takes game hours, adds a lasting bonus.
class_name ConstructionDef
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
## Cost (cents) of each level; its size is the maximum level.
@export var level_costs: PackedInt32Array = PackedInt32Array()
@export var build_hours: int = 4
@export var min_reputation: int = 0

@export_group("Bonus per level")
@export var raw_capacity_bonus: int = 0
@export var finished_capacity_bonus: int = 0
@export var extra_machine_slots: int = 0
@export var order_rate_bonus_percent: int = 0
@export var power_discount_percent: int = 0
@export var haul_speed_bonus_percent: int = 0
