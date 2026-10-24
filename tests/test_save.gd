extends TestCase


func _busy_sim() -> Simulation:
	var sim := new_sim(99)
	var o: Dictionary = sim.orders.with_status(OrderManager.OFFERED)[0]
	sim.accept_order(o.id)
	sim.buy_material(250)
	sim.advance_ticks(days(sim, 1.3))
	return sim


func test_round_trip_identical() -> void:
	var a := _busy_sim()
	var json := a.to_json()
	var b := blank_sim()
	check(b.load_json(json), "load ok")
	check_eq(b.to_json(), json, "state identical after load")
	a.advance_ticks(days(a, 1))
	b.advance_ticks(days(b, 1))
	check_eq(b.to_json(), a.to_json(), "identical after another day (rng restored)")
	check(typeof(b.state.cash) == TYPE_INT, "cash is int after JSON")


func test_versioning() -> void:
	var a := _busy_sim()
	var d := a.to_save_dict()
	check_eq(int(d.save_version), SaveMigrations.CURRENT_VERSION, "version written")
	d.erase("save_version")
	var b := blank_sim()
	check(b.load_save_dict(d), "versionless save migrates")
	var future := a.to_save_dict()
	future.save_version = SaveMigrations.CURRENT_VERSION + 1
	var c := blank_sim()
	check(not c.load_save_dict(future), "newer save refused")


func test_file_io() -> void:
	var a := _busy_sim()
	var path := "user://test_save.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(a.to_json())
	f.close()
	var b := blank_sim()
	check(b.load_json(FileAccess.get_file_as_string(path)), "load from file")
	check_eq(b.to_json(), a.to_json(), "file round trip")
	DirAccess.remove_absolute(path)
