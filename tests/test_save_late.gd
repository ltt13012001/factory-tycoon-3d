## Saves of a big company (factories next door, branches, executives,
## construction) and the safety net around the save file.
extends TestCase

const SaveFile := preload("res://autoload/save_manager.gd")
const DIR := "user://test_saves/"


func _late_sim() -> Simulation:
	var sim := new_sim(7)
	sim.state.cash = 1000000000
	sim.state.day_start_cash = sim.state.cash
	sim.set_auto_buy(true)
	sim.set_auto_ship(true)
	sim.set_auto_accept(true)
	for slot in sim.buildings.machine_slots():
		if sim.production.machine_in_slot(slot).is_empty():
			sim.buy_machine(slot)
	for i in 4:
		sim.hire(EmployeeManager.OPERATOR)
	sim.hire(EmployeeManager.WAREHOUSE)
	sim.hire(EmployeeManager.TECHNICIAN)
	sim.hire(EmployeeManager.MANAGER)
	sim.state.company_tier = 2
	sim.hire_executive("production_director")
	sim.hire_executive("sales_director")
	sim.upgrade_line_speed()
	var l: LocationDef = sim.content.locations["lot_2"]
	sim.expand("lot_2")
	sim.advance_ticks(maxi(l.survey_hours, 1) * sim.config.ticks_per_hour)
	sim.expand("lot_2")
	sim.advance_ticks(l.build_hours * sim.config.ticks_per_hour)
	sim.hire_site_head("lot_2")
	for i in 4:
		sim.buy_machine(i, "", "lot_2")
		sim.hire(EmployeeManager.OPERATOR, "lot_2")
	sim.hire(EmployeeManager.WAREHOUSE, "lot_2")
	var h: LocationDef = sim.content.locations["hai_phong"]
	check(sim.expand("hai_phong").ok, "survey")
	sim.advance_ticks(h.survey_hours * sim.config.ticks_per_hour)
	check(sim.expand("hai_phong").ok, "build hp")
	sim.advance_ticks(h.build_hours * sim.config.ticks_per_hour)
	sim.hire_site_head("hai_phong")
	sim.buy_line("hai_phong")
	sim.expand("bac_ninh")
	sim.build("sales_office")
	sim.advance_ticks(days(sim, 1.37))
	return sim


func test_late_game_round_trip() -> void:
	var a := _late_sim()
	print("       sites %s, machines %d, staff %d, construction %s" % [str(a.state.sites.map(func(s): return s.id + ":" + s.status)), a.state.machines.size(), a.state.employees.size(), str(a.state.construction)])
	var json := a.to_json()
	var b := blank_sim()
	check(b.load_json(json), "load ok")
	check_eq(b.to_json(), json, "identical after load")
	for i in 6:
		a.advance_ticks(days(a, 0.5) + 17)
		b.advance_ticks(days(b, 0.5) + 17)
		var ja := a.to_json()
		var jb := b.to_json()
		check(ja == jb, "identical after %d half-days" % (i + 1))
		if ja != jb:
			_diff(a.to_save_dict(), b.to_save_dict())
			break
		# save again mid-way, like the 60 s autosave
		b = blank_sim()
		b.load_json(ja)


func _diff(x: Dictionary, y: Dictionary) -> void:
	for k in x:
		if JSON.stringify(x[k]) != JSON.stringify(y.get(k)):
			print("   DIFF ", k, "\n     a=", JSON.stringify(x[k]).left(600), "\n     b=", JSON.stringify(y.get(k)).left(600))



func _clear_dir() -> void:
	if not DirAccess.dir_exists_absolute(DIR):
		return
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + f)


func test_write_keeps_backup() -> void:
	_clear_dir()
	var a := _late_sim()
	var first := SaveFile.save_text(a)
	check(SaveFile.write_slot(first, DIR), "first save")
	a.advance_ticks(50)
	var second := SaveFile.save_text(a)
	check(SaveFile.write_slot(second, DIR), "second save")
	check_eq(FileAccess.get_file_as_string(DIR + "slot_1.json"), second, "slot holds the newest save")
	check_eq(FileAccess.get_file_as_string(DIR + "slot_1.bak.json"), first, "backup holds the one before")
	check(not FileAccess.file_exists(DIR + "slot_1.tmp"), "no temporary file left")
	_clear_dir()


func test_cut_off_save_falls_back() -> void:
	var a := _late_sim()
	var good := SaveFile.save_text(a)
	a.advance_ticks(50)
	var newer := SaveFile.save_text(a)
	var cut := newer.left(newer.length() / 2)
	var b := blank_sim()
	var r: Dictionary = SaveFile.load_best(b, [["slot", cut], ["backup", good], ["web", ""]])
	check(r.ok, "loads the backup when the slot is cut off")
	check_eq(r.note, "backup", "says the backup was used")
	check_eq(b.state.tick, a.state.tick - 50, "backup game time")
	var c := blank_sim()
	r = SaveFile.load_best(c, [["slot", good], ["backup", ""], ["web", newer]])
	check(r.ok and r.source == "web", "takes the newest copy (browser storage)")
	check_eq(c.state.tick, a.state.tick, "newest game time")
	var d := blank_sim()
	r = SaveFile.load_best(d, [["slot", "{garbage"], ["backup", ""], ["web", ""]])
	check(not r.ok and r.note == "broken", "unreadable save is reported, not loaded")
	var future: Dictionary = JSON.parse_string(good)
	future.save_version = SaveMigrations.CURRENT_VERSION + 1
	r = SaveFile.load_best(blank_sim(), [["slot", JSON.stringify(future)]])
	check(not r.ok and r.note == "newer", "save from a newer version is reported")
	r = SaveFile.load_best(blank_sim(), [["slot", ""], ["backup", ""]])
	check(not r.ok and r.note == "", "no save at all")


func test_save_code_round_trip() -> void:
	var a := _late_sim()
	var json := SaveFile.save_text(a)
	var code: String = SaveFile.encode(json)
	check(code.begins_with(SaveFile.CODE_PREFIX), "code prefix")
	check(code.length() < json.length(), "code is shorter than the save (%d < %d)" % [code.length(), json.length()])
	check_eq(SaveFile.decode(code), json, "code decodes to the save")
	check_eq(SaveFile.decode("  " + code + "\n"), json, "spaces around a pasted code are ignored")
	check_eq(SaveFile.decode("hello"), "", "not a code")
	var b := blank_sim()
	check(b.load_json(SaveFile.decode(code)), "game loads from the code")
	check_eq(b.state.sites.size(), a.state.sites.size(), "sites came along")
