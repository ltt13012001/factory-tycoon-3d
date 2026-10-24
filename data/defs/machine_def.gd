class_name MachineDef
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var price: int = 0
@export var cycle_ticks: int = 24
@export var output_product_id: String = ""
## Chance (in percent) that a finished cycle produces a defective unit.
@export var defect_percent: int = 5
@export var power_cost_per_cycle: int = 15
@export var resale_percent: int = 50
@export var operators_required: int = 1
## Boxes the pallet next to the machine can hold before the machine stops.
@export var output_buffer_capacity: int = 20
## Scene used by the 3D view. Swap this path to replace the placeholder model.
@export_file("*.tscn") var view_scene: String = ""
