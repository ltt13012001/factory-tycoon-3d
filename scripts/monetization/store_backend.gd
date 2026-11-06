## A store that sells the diamond packs. Subclasses talk to Apple's or
## Google's billing; the Monetization autoload picks one.
class_name StoreBackend
extends Node

## Prices came back from the store (localised text per product id).
signal products_loaded
## A purchase ended. token is what finish() needs once the diamonds are
## credited and saved; message is shown when ok is false ("" = cancelled).
signal purchase_result(product_id: String, transaction_id: String, ok: bool, message: String, token: String)

var prices := {}


func available() -> bool:
	return false


## Localised price ("25.000 ₫"), or "" until the store answers.
func price_of(product_id: String) -> String:
	return prices.get(product_id, "")


func buy(_product_id: String) -> void:
	pass


## Tells the store the purchase was delivered (consumed).
func finish(_token: String) -> void:
	pass
