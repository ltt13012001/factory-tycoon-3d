## Google Play Billing through the "GodotGooglePlayBilling" Android plugin
## (godot-sdk-integrations/godot-google-play-billing). Purchases are
## consumed only after the diamonds are credited and saved; purchases left
## unconsumed (a crash, a pending payment) are picked up on the next start.
## The plugin's API changed names between versions, so both are handled.
class_name GooglePlayStore
extends StoreBackend

const SINGLETON := "GodotGooglePlayBilling"
const PURCHASED := 1

var _billing: Object


static func plugin_present() -> bool:
	return OS.has_feature("android") and Engine.has_singleton(SINGLETON)


func _ready() -> void:
	_billing = Engine.get_singleton(SINGLETON)
	_on("connected", _on_connected)
	_on("purchases_updated", _on_purchases)
	_on("purchase_error", func(_code, msg): purchase_result.emit("", "", false, str(msg), ""))
	_on("product_details_query_completed", _on_details)
	_on("sku_details_query_completed", _on_details)
	_on("query_purchases_response", func(r): _on_purchases(r.get("purchases", [])))
	_billing.startConnection()


func _on(sig: String, f: Callable) -> void:
	if _billing.has_signal(sig):
		_billing.connect(sig, f)


func available() -> bool:
	return _billing != null


func _ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for p in DiamondManager.PACKS:
		ids.append(MonetizationConfig.product_id(p.id))
	return ids


func _on_connected() -> void:
	if _billing.has_method("queryProductDetails"):
		_billing.queryProductDetails(_ids(), "inapp")
	elif _billing.has_method("querySkuDetails"):
		_billing.querySkuDetails(_ids(), "inapp")
	if _billing.has_method("queryPurchases"):
		var r = _billing.queryPurchases("inapp")
		if r is Dictionary:
			_on_purchases(r.get("purchases", []))


func _on_details(list: Array) -> void:
	for d in list:
		var id := str(d.get("product_id", d.get("sku", "")))
		var price := str(d.get("price", ""))
		if d.has("one_time_purchase_offer_details"):
			price = str(d.one_time_purchase_offer_details.get("formatted_price", price))
		if id != "":
			prices[id] = price
	products_loaded.emit()


func buy(product_id: String) -> void:
	_billing.purchase(product_id)


func finish(token: String) -> void:
	if token != "":
		_billing.consumePurchase(token)


func _on_purchases(list: Array) -> void:
	for p in list:
		if int(p.get("purchase_state", PURCHASED)) != PURCHASED:
			continue  # pending (e.g. paid in cash at a shop): delivered later
		var ids: Array = p.get("products", p.get("skus", [p.get("sku", "")]))
		var token := str(p.get("purchase_token", ""))
		for id in ids:
			purchase_result.emit(str(id), str(p.get("order_id", token)), true, "", token)
