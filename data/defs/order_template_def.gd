class_name OrderTemplateDef
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var product_id: String = ""
@export var min_quantity: int = 30
@export var max_quantity: int = 90
## Deadline = round(quantity / quantity_per_day) + 1 days, clamped.
@export var quantity_per_day: int = 45
@export var min_deadline_days: int = 1
@export var max_deadline_days: int = 3
@export var offer_lifetime_days: int = 1
@export var customer_names: PackedStringArray = PackedStringArray()
