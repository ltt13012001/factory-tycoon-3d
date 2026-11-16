class_name ProductDef
extends Resource

@export var id: String = ""
@export var display_name: String = "":
	get:
		return TranslationServer.translate(display_name)
## Short unit word for the UI ("hộp", "bình", "kệ").
@export var unit_name: String = "cái":
	get:
		return TranslationServer.translate(unit_name)
@export var material_id: String = ""
@export var material_per_unit: int = 1
## Base sell price per unit, in cents.
@export var base_price: int = 0
## Colour of the item on pallets and trucks in the 3D view.
@export var color: Color = Color.WHITE
