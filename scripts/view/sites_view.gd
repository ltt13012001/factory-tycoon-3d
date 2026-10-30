## The plots east of the first factory and what stands on them: land for
## sale, a fenced plot, a hall under construction, or a working factory hall
## (its machines and staff are drawn by FactoryView like the first
## factory's). Each plot is rebuilt only when what it shows changes.
extends Node3D

var _plots := {}  # location id -> Node3D
var _signatures := {}
var _labels := {}  # location id -> Label3D with the live status line
var _timer := 0.0
var _paint: Material
var _steel: Material
var _paving: Material


func _ready() -> void:
	_paint = Palette.surface("paint")
	_steel = Palette.surface("steel")
	_paving = Palette.surface("paving")
	_refresh()


func _process(delta: float) -> void:
	_timer += delta
	if _timer < 0.5 or GameManager.sim == null:
		return
	_timer = 0.0
	_refresh()


func _refresh() -> void:
	var sim := GameManager.sim
	if sim == null:
		return
	for id in FactoryLayout.PLOTS:
		if not sim.content.locations.has(id):
			continue
		var s := sim.expansion.site(id)
		var progress := 0
		if not s.is_empty() and int(s.total_ticks) > 0 and s.status == ExpansionManager.BUILDING:
			progress = 100 - int(s.ticks_left) * 100 / int(s.total_ticks)
		var sig := "none" if s.is_empty() else "%s|%d|%s|%d" % [s.status, s.automation, s.head != "", progress / 20]
		if _signatures.get(id, "") != sig:
			_signatures[id] = sig
			_rebuild(sim, id, s, progress)
		_update_label(sim, id, s, progress)


func _rebuild(sim: Simulation, id: String, s: Dictionary, progress: int) -> void:
	if _plots.has(id):
		_plots[id].queue_free()
	var root := Node3D.new()
	root.position = FactoryLayout.PLOTS[id]
	add_child(root)
	_plots[id] = root
	var l: LocationDef = sim.content.locations[id]
	var b := MeshBatch.new()
	var flat := MeshBatch.new()
	var half := FactoryLayout.PLOT_SIZE / 2.0
	var status: String = "" if s.is_empty() else s.status
	if status == "":
		_for_sale(b, flat, half)
	else:
		_fence(b, half)
		flat.box(Vector3(half.x * 2 - 1, 0.06, half.y * 2 - 1), Vector3(0, 0.03, 0), Color("b8b2a4"), _paving)
		flat.box(Vector3(3.2, 0.07, 12.0), Vector3(-8.0, 0.035, 12.5), Color("6d7177"), _paving)
		match status:
			ExpansionManager.LAND:
				_survey_stakes(b)
			ExpansionManager.BUILDING:
				_construction(b, flat, progress)
			ExpansionManager.READY:
				_factory(b, flat, s, sim)
	b.build(root)
	flat.build(root, false)
	if status == ExpansionManager.READY:
		# Only the office picks the plot, so the machines and staff inside stay clickable.
		var o_lo := FactoryLayout.SITE_OFFICE_MIN
		var o_hi := FactoryLayout.SITE_OFFICE_MAX
		Palette.pick_body(root, Vector3(o_hi.x - o_lo.x, 3.0, o_hi.y - o_lo.y), Vector3((o_lo.x + o_hi.x) / 2.0, 1.5, (o_lo.y + o_hi.y) / 2.0), "site", l.order)
	else:
		Palette.pick_body(root, Vector3(half.x * 2, 6.0, half.y * 2), Vector3(0, 3.0, 0), "site", l.order)
	var title := Palette.label3d(root, l.display_name.to_upper(), Vector3(0, 11.5, 0), 52, Color.WHITE)
	title.name = "Title"
	_labels[id] = Palette.label3d(root, "", Vector3(0, 9.2, 0), 38, Color("ffe082"))


func _update_label(sim: Simulation, id: String, s: Dictionary, progress: int) -> void:
	var lbl: Label3D = _labels.get(id)
	if lbl == null:
		return
	var l: LocationDef = sim.content.locations[id]
	var text := ""
	var color := Color("ffe082")
	if s.is_empty():
		var reason := sim.expansion.block_reason(id)
		text = "Đất bán: %s" % Fmt.money(l.land_cost) if reason == "" else "Đất bán · " + reason
	else:
		match s.status:
			ExpansionManager.LAND:
				text = "Đất của bạn · sẵn sàng xây xưởng"
			ExpansionManager.BUILDING:
				text = "Đang xây %d%%" % progress
			ExpansionManager.READY:
				var machines := sim.production.machines_at(id).size()
				var staff := sim.employees.staff_at(id).size()
				text = "%d/%d máy · %d nhân viên" % [machines, l.max_lines, staff]
				if machines == 0:
					text = "Xưởng trống · vào Xây dựng để đặt máy"
				elif s.head == "":
					text += " · chưa có xưởng trưởng"
					color = Color("ffcc80")
				else:
					text = "%s · %s" % [s.head, text]
					color = Color("b9f6ca")
	lbl.text = text
	lbl.modulate = color


func _for_sale(b: MeshBatch, flat: MeshBatch, half: Vector2) -> void:
	# Corner stakes with red-white tape and a "for sale" board by the road.
	for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		b.box(Vector3(0.15, 1.0, 0.15), Vector3(c.x * half.x, 0.5, c.y * half.y), Color("eceff1"), _paint)
		b.box(Vector3(0.18, 0.2, 0.18), Vector3(c.x * half.x, 0.9, c.y * half.y), Color("d32f2f"), _paint)
	var board := Vector3(0, 0, half.y - 1.5)
	for x in [-1.3, 1.3]:
		b.box(Vector3(0.14, 2.6, 0.14), board + Vector3(x, 1.3, 0), Color("6d4c41"))
	b.box(Vector3(3.2, 1.4, 0.1), board + Vector3(0, 2.0, 0), Color("f9a825"), _paint)
	b.box(Vector3(2.9, 1.1, 0.11), board + Vector3(0, 2.0, 0), Color("fff8e1"), _paint)
	flat.box(Vector3(half.x * 2 - 2, 0.03, half.y * 2 - 2), Vector3(0, 0.015, 0), Color("7da85a"))


func _fence(b: MeshBatch, half: Vector2) -> void:
	var post := Color("8d969d")
	for side in [-1, 1]:
		for i in 12:
			var x := -half.x + i * half.x * 2 / 11.0
			if side > 0 and x > -half.x + 0.5 and x < -half.x + 6.0:
				continue  # gateway for the drive
			b.box(Vector3(0.1, 1.6, 0.1), Vector3(x, 0.8, side * half.y), post, _steel)
		for i in 14:
			var z := -half.y + i * half.y * 2 / 13.0
			b.box(Vector3(0.1, 1.6, 0.1), Vector3(side * half.x, 0.8, z), post, _steel)
	b.box(Vector3(half.x * 2, 0.06, 0.04), Vector3(0, 1.5, -half.y), post, _steel)
	b.box(Vector3(half.x * 2 - 6.0, 0.06, 0.04), Vector3(3.0, 1.5, half.y), post, _steel)
	for side in [-1, 1]:
		b.box(Vector3(0.04, 0.06, half.y * 2), Vector3(side * half.x, 1.5, 0), post, _steel)


func _survey_stakes(b: MeshBatch) -> void:
	for x in [-9.0, 9.0]:
		for z in [-9.0, 9.0]:
			b.box(Vector3(0.12, 0.8, 0.12), Vector3(x, 0.4, z), Color("ff7043"), _paint)
	b.box(Vector3(18.0, 0.02, 0.06), Vector3(0, 0.75, -9.0), Color("ff7043"))
	b.box(Vector3(18.0, 0.02, 0.06), Vector3(0, 0.75, 9.0), Color("ff7043"))


func _construction(b: MeshBatch, flat: MeshBatch, progress: int) -> void:
	flat.box(Vector3(18.4, 0.3, 18.4), Vector3(0, 0.15, 0), Color("9e9e9e"), _paving)
	# Steel columns rise with the progress, then the roof trusses.
	var h := 6.5 * clampf(progress / 60.0, 0.15, 1.0)
	for x in [-9.0, -4.5, 0.0, 4.5, 9.0]:
		for z in [-9.0, 9.0]:
			b.box(Vector3(0.35, h, 0.35), Vector3(x, 0.3 + h / 2.0, z), Color("e65100"), _paint)
	if progress >= 60:
		for x in [-9.0, -4.5, 0.0, 4.5, 9.0]:
			b.box(Vector3(0.3, 0.4, 18.0), Vector3(x, 6.9, 0), Color("e65100"), _paint)
	if progress >= 80:
		for z in [-9.0, 9.0]:
			b.box(Vector3(18.0, 3.0, 0.15), Vector3(0, 1.8, z), Color("cfd8dc"), _steel)
	# Tower crane
	var c := Vector3(-11.5, 0, -11.5)
	b.box(Vector3(1.0, 16.0, 1.0), c + Vector3(0, 8.0, 0), Color("fbc02d"), _paint)
	b.box(Vector3(14.0, 0.6, 0.6), c + Vector3(5.0, 16.3, 0), Color("fbc02d"), _paint)
	b.box(Vector3(2.0, 1.2, 1.2), c + Vector3(-2.5, 15.8, 0), Color("616161"), _steel)
	b.bar(c + Vector3(9.0, 16.0, 0), c + Vector3(9.0, 9.0, 0), 0.05, Color("424242"))
	for k in 3:
		Palette.pallet(b, Vector3(6.0 + k * 1.5, 0.3, 11.0))
		b.box(Vector3(1.0, 0.5, 1.0), Vector3(6.0 + k * 1.5, 0.7, 11.0), Color("90a4ae"), _steel)


func _factory(b: MeshBatch, flat: MeshBatch, s: Dictionary, sim: Simulation) -> void:
	# A hall like the first factory's: the machines, staff and their goods
	# are the real ones (FactoryView), this draws the building around them.
	var wall := Color("d9dad5")
	var trim := Color("37474f")
	var lo := FactoryLayout.SITE_HALL_MIN
	var hi := FactoryLayout.SITE_HALL_MAX
	var w := hi.x - lo.x
	var d := hi.y - lo.y
	var c := Vector3((lo.x + hi.x) / 2.0, 0, (lo.y + hi.y) / 2.0)
	flat.box(Vector3(w, 0.06, d), c + Vector3(0, 0.07, 0), Color("aab0ae"), _paving)
	# High back wall with windows, side walls, a low front wall with the
	# door so the isometric camera sees in.
	b.box(Vector3(w, 6.0, 0.3), Vector3(c.x, 3.0, lo.y), wall, _paint)
	for i in 5:
		b.box(Vector3(2.4, 1.2, 0.05), Vector3(c.x - 7.6 + i * 3.8, 4.6, lo.y + 0.17), Color("8fb6d6"), _steel)
	b.box(Vector3(w + 0.1, 0.4, 0.5), Vector3(c.x, 6.1, lo.y), trim, _paint)
	for side in [-1, 1]:
		b.box(Vector3(0.3, 3.0, d), Vector3(c.x + side * w / 2.0, 1.5, c.z), wall, _paint)
		b.box(Vector3(0.34, 0.25, d), Vector3(c.x + side * w / 2.0, 3.0, c.z), trim, _paint)
	var door := FactoryLayout.SITE_DOOR
	var left := door.x - lo.x
	var right := hi.x - door.y
	b.box(Vector3(left, 1.2, 0.3), Vector3(lo.x + left / 2.0, 0.6, hi.y), wall, _paint)
	b.box(Vector3(right, 1.2, 0.3), Vector3(door.y + right / 2.0, 0.6, hi.y), wall, _paint)
	for x in [door.x, door.y]:
		b.box(Vector3(0.35, 1.5, 0.4), Vector3(x, 0.75, hi.y), trim, _paint)
	# Painted bays, one per machine place.
	var l: LocationDef = sim.content.locations[s.id]
	for i in l.max_lines:
		var p := FactoryLayout.slot_position(i, s.id) - FactoryLayout.plot(s.id) + Vector3(0.6, 0.11, 0)
		for z in [-1.15, 1.15]:
			flat.box(Vector3(4.6, 0.02, 0.1), p + Vector3(0, 0, z), Color("e3b51f"))
		for x in [-2.3, 2.3]:
			flat.box(Vector3(0.1, 0.02, 2.4), p + Vector3(x, 0, 0), Color("e3b51f"))
	# Dispatch pallets by the door: finished goods wait here for the truck to the store.
	var st_lo := FactoryLayout.SITE_STACK_MIN
	var st_hi := FactoryLayout.SITE_STACK_MAX
	for k in 2:
		var pp := Vector3((st_lo.x + st_hi.x) / 2.0, 0.08, st_lo.y + 0.4 + k * 0.8)
		Palette.pallet(b, pp)
		b.box(Vector3(1.0, 0.5 + k * 0.3, 0.7), pp + Vector3(0, 0.33 + k * 0.15, 0), Color("c8a46e"))
	# Rest area: a table with two benches and a sunshade.
	var t_lo := FactoryLayout.SITE_TABLE_MIN
	var t_hi := FactoryLayout.SITE_TABLE_MAX
	var tc := Vector3((t_lo.x + t_hi.x) / 2.0, 0, (t_lo.y + t_hi.y) / 2.0)
	b.box(Vector3(t_hi.x - t_lo.x, 0.08, t_hi.y - t_lo.y), tc + Vector3(0, 0.75, 0), Color("a1887f"))
	for x in [-1.6, 1.6]:
		b.box(Vector3(0.1, 0.72, 0.8), tc + Vector3(x, 0.36, 0), Color("6d4c41"))
	for z in [-1.1, 1.1]:
		b.box(Vector3(t_hi.x - t_lo.x, 0.08, 0.45), tc + Vector3(0, 0.45, z), Color("8d6e63"))
	b.cylinder(0.05, 2.4, tc + Vector3(0, 1.2, 0), Color("9e9e9e"), _steel)
	b.cylinder(1.9, 0.35, tc + Vector3(0, 2.45, 0), Color("ef6c00"), _paint, 0.1, Vector3.ZERO, 8)
	# Automation: one storage tank per level behind the hall.
	for k in int(s.automation):
		var silo := Vector3(-6.0 + k * 4.0, 0, lo.y - 1.05)
		b.cylinder(0.85, 5.0, silo + Vector3(0, 2.5, 0), Color("dfe3e6"), _steel)
		b.sphere(0.85, silo + Vector3(0, 5.0, 0), Color("cfd4d8"), _steel, Vector3(1, 0.5, 1))
	# Office, with a light on and a flag when there is a factory manager.
	var o_lo := FactoryLayout.SITE_OFFICE_MIN
	var o_hi := FactoryLayout.SITE_OFFICE_MAX
	var office := Vector3((o_lo.x + o_hi.x) / 2.0, 0, (o_lo.y + o_hi.y) / 2.0)
	var od := o_hi.y - o_lo.y
	b.box(Vector3(o_hi.x - o_lo.x, 2.8, od), office + Vector3(0, 1.4, 0), Color("eceff1"), _paint)
	for side in [-1, 1]:
		b.box(Vector3(4.6, 1.0, 0.05), office + Vector3(0, 1.6, side * (od / 2.0 + 0.02)), Color("8fb6d6"), _steel)
	b.box(Vector3(o_hi.x - o_lo.x + 0.3, 0.25, od + 0.3), office + Vector3(0, 2.9, 0), trim, _paint)
	if s.head != "":
		b.box(Vector3(1.2, 0.5, 0.06), office + Vector3(-1.6, 2.3, od / 2.0 + 0.05), Color("fff3c4"), Palette.mat(Color("fff3c4"), 1.2))
		var pole := office + Vector3(2.4, 0, od / 2.0 + 0.5)
		b.cylinder(0.05, 4.5, pole + Vector3(0, 2.25, 0), Color("cfd8dc"), _steel)
		b.box(Vector3(1.1, 0.7, 0.03), pole + Vector3(0.58, 4.1, 0), Color("d32f2f"))
