class_name MaterialDef
extends Resource

@export var id: String = ""
@export var display_name: String = "":
	get:
		return TranslationServer.translate(display_name)
## Price per unit, in cents.
@export var unit_price: int = 0
