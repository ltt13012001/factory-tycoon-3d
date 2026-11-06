## Apple In-App Purchase (StoreKit) through Godot's official "InAppStore"
## iOS plugin (godot-ios-plugins). Transactions are finished only after the
## diamonds are credited and saved, so a purchase interrupted by a crash is
## delivered again on the next launch.
class_name AppleStore
extends StoreBackend

const SINGLETON := "InAppStore"

var _store: Object


static func plugin_present() -> bool:
	return OS.has_feature("ios") and Engine.has_singleton(SINGLETON)


func _ready() -> void:
	_store = Engine.get_singleton(SINGLETON)
	_store.set_auto_finish_transaction(false)
	var ids := PackedStringArray()
	for p in DiamondManager.PACKS:
		ids.append(MonetizationConfig.product_id(p.id))
	_store.request_product_info({"product_ids": ids})


func available() -> bool:
	return _store != null


func buy(product_id: String) -> void:
	if _store.purchase({"product_id": product_id}) != OK:
		purchase_result.emit(product_id, "", false, "Không mở được App Store, thử lại sau.", "")


func finish(token: String) -> void:
	if token != "":
		_store.finish_transaction(token)


func _process(_delta: float) -> void:
	while _store and _store.get_pending_event_count() > 0:
		_handle(_store.pop_pending_event())


func _handle(e: Dictionary) -> void:
	match str(e.get("type", "")):
		"product_info":
			if e.get("result", "") == "ok":
				var ids: Array = e.get("ids", [])
				var texts: Array = e.get("localized_prices", e.get("prices", []))
				for i in mini(ids.size(), texts.size()):
					prices[ids[i]] = str(texts[i])
				products_loaded.emit()
		"purchase":
			var id := str(e.get("product_id", ""))
			match str(e.get("result", "")):
				"ok":
					purchase_result.emit(id, str(e.get("transaction_id", "")), true, "", id)
				"progress":
					pass
				_:
					# Cancelled by the player or refused by the store.
					purchase_result.emit(id, "", false, "", "")
