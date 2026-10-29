class_name MachineDef
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var price: int = 0
@export var cycle_ticks: int = 24
@export var output_product_id: String = ""
## Chance (in percent) that a finished cycle produces a defective unit.
@export var defect_percent: int = 5
@export var power_cost_per_cycle: int = 15
@export var resale_percent: int = 50
## 0 means the machine runs by itself (automated).
@export var operators_required: int = 1
## Units the pallet next to the machine can hold before the machine stops.
@export var output_buffer_capacity: int = 40

@export_group("Unlock")
@export var min_reputation: int = 0
@export var min_day: int = 1

@export_group("Upgrades")
@export var max_level: int = 5
## Each level above 1 makes the cycle this many percent shorter.
@export var upgrade_speed_percent: int = 15
## Upgrade to level L costs price * percent / 100 * (L - 1).
@export var upgrade_cost_percent: int = 50

@export_group("Wear")
## Condition (0-100) drops by 1 every this many cycles.
@export var wear_cycles: int = 3
## Below this condition each cycle may break the machine.
@export var fragile_below: int = 30
@export var breakdown_percent: int = 2
## Repair cost per missing condition point, in cents.
@export var repair_cost_per_point: int = 150
@export var repair_ticks: int = 60

@export_group("View")
## Model variant drawn by the 3D view: basic, blow, industrial, press, auto.
@export var model: String = "basic"
@export var color: Color = Color("3d7cc9")
