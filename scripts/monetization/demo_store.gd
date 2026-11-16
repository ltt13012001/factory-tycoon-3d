## Pretend store for development builds: buying asks for a confirmation
## and credits the pack without any payment. Never used in a release build
## unless started with `-- --demo-monetization`.
class_name DemoStore
extends StoreBackend

var instant := false
var _n := 0


func available() -> bool:
	return true


func price_of(product_id: String) -> String:
	var p := DiamondManager.pack(MonetizationConfig.pack_id(product_id))
	var price := str(p.get("price", "?"))
	if not Fmt.is_vietnamese():
		price = price.replace(",", ".")  # the fallback prices are written "0,99 USD"
	return tr("%s (thử)") % price


func buy(product_id: String) -> void:
	_n += 1
	var txn := "demo-%d-%d" % [Time.get_ticks_msec(), _n]
	if instant:
		purchase_result.emit(product_id, txn, true, "", txn)
		return
	var dlg := ConfirmationDialog.new()
	dlg.title = tr("Mua thử")
	dlg.dialog_text = tr("Bản thử nghiệm: nhận gói này miễn phí, không trừ tiền thật?")
	dlg.ok_button_text = tr("Nhận")
	dlg.cancel_button_text = tr("Hủy")
	add_child(dlg)
	dlg.confirmed.connect(func(): purchase_result.emit(product_id, txn, true, "", txn))
	dlg.canceled.connect(func(): purchase_result.emit(product_id, txn, false, "", ""))
	dlg.visibility_changed.connect(func():
		if not dlg.visible:
			dlg.queue_free())
	dlg.popup_centered()
