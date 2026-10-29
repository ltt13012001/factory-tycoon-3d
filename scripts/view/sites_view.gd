## The plots east of the first factory and what stands on them: land for
## sale, a fenced plot, a hall under construction, or a working factory whose
## production lines, automation and manager follow the simulation. Each plot
## is rebuilt only when what it shows changes.
extends Node3D

const LINE_COLORS := [Color("3d7cc9"), Color("2e9e8f"), Color("e08a2e")]

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
		var sig := "none" if s.is_empty() else "%s|%d|%d|%s|%d" % [s.status, s.lines, s.automation, s.head != "", progress / 20]
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
		flat.box(Vector3(3.0, 0.07, half.y + 6.0), Vector3(-half.x + 3.0, 0.035, half.y / 2.0 + 3.0), Color("6d7177"), _paving)
		match status:
			ExpansionManager.LAND:
				_survey_stakes(b)
			ExpansionManager.BUILDING:
				_construction(b, flat, progress)
			ExpansionManager.READY:
				_factory(b, flat, s, sim)
	b.build(root)
	flat.build(root, false)
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
				if s.head == "":
					text = "Chưa có xưởng trưởng!"
					color = Color("ff8a80")
				else:
					text = "%s · %d dây chuyền · %s/ngày" % [s.head, s.lines, Fmt.money(sim.expansion.daily_income(s))]
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
	var wall := Color("d9dad5")
	var trim := Color("37474f")
	var w := 18.0
	var d := 17.0
	var c := Vector3(0, 0, -1.5)
	flat.box(Vector3(w, 0.32, d), c + Vector3(0, 0.16, 0), Color("aab0ae"), _paving)
	# High back wall with windows, side walls, a low front wall so the
	# isometric camera sees in.
	b.box(Vector3(w, 6.0, 0.3), c + Vector3(0, 3.3, -d / 2.0), wall, _paint)
	for i in 5:
		b.box(Vector3(2.4, 1.2, 0.05), c + Vector3(-7.0 + i * 3.5, 4.8, -d / 2.0 + 0.17), Color("8fb6d6"), _steel)
	for side in [-1, 1]:
		b.box(Vector3(0.3, 3.0, d), c + Vector3(side * w / 2.0, 1.8, 0), wall, _paint)
		b.box(Vector3(0.34, 0.25, d), c + Vector3(side * w / 2.0, 3.3, 0), trim, _paint)
	b.box(Vector3(w, 1.2, 0.3), c + Vector3(0, 0.9, d / 2.0), wall, _paint)
	b.box(Vector3(w + 0.1, 0.4, 0.5), c + Vector3(0, 6.3, -d / 2.0), trim, _paint)
	# Production lines: up to 3 x 3 machines with a conveyor along each row.
	var lines := int(s.lines)
	var running: bool = s.head != ""
	var l: LocationDef = sim.content.locations[s.id]
	for i in l.max_lines:
		var col := i % 3
		var row := i / 3
		var p := c + Vector3(-5.5 + col * 5.5, 0.32, -5.0 + row * 5.0)
		if i >= lines:
			flat.box(Vector3(3.6, 0.02, 2.2), p + Vector3(0, 0.01, 0), Color("e3b51f"))
			continue
		var color: Color = LINE_COLORS[row % LINE_COLORS.size()]
		b.box(Vector3(3.2, 0.3, 1.8), p + Vector3(0, 0.15, 0), Color("455a64"), _steel)
		b.box(Vector3(2.4, 1.4, 1.5), p + Vector3(-0.3, 1.0, 0), color, _paint)
		b.box(Vector3(0.8, 0.9, 1.0), p + Vector3(1.3, 0.75, 0), Color("cfd8dc"), _steel)
		b.cylinder(0.35, 0.8, p + Vector3(-0.9, 2.1, 0), Color("b0bec5"), _steel, 0.15)
		b.cylinder(0.06, 0.6, p + Vector3(1.4, 1.5, 0.6), Color("37474f"), _steel)
		b.sphere(0.13, p + Vector3(1.4, 1.85, 0.6), Palette.STATUS_RUN if running else Palette.STATUS_STOP, Palette.mat(Palette.STATUS_RUN if running else Palette.STATUS_STOP, 1.5))
		if running:
			b.cylinder(0.25, 1.1, p + Vector3(0.2, 0.55, 1.4), Palette.OPERATOR, null)
			b.sphere(0.2, p + Vector3(0.2, 1.3, 1.4), Palette.HELMET)
		if int(s.automation) > 0:
			# Robot arm feeding the line
			b.cylinder(0.25, 0.4, p + Vector3(1.5, 0.5, -0.9), Color("ff8f00"), _paint)
			b.bar(p + Vector3(1.5, 0.7, -0.9), p + Vector3(1.0, 1.7, -0.4), 0.18, Color("ff8f00"), _paint, true)
	for row in 3:
		if row * 3 < lines:
			flat.box(Vector3(15.0, 0.25, 0.5), c + Vector3(0, 0.45, -3.6 + row * 5.0), Color("546e7a"))
	# Automation: one silo per level behind the hall.
	for k in int(s.automation):
		var silo := c + Vector3(-6.0 + k * 4.0, 0, -d / 2.0 - 2.4)
		b.cylinder(1.3, 6.0, silo + Vector3(0, 4.0, 0), Color("dfe3e6"), _steel)
		b.sphere(1.3, silo + Vector3(0, 7.0, 0), Color("cfd4d8"), _steel, Vector3(1, 0.5, 1))
		for a in 4:
			var ang := a * TAU / 4.0
			b.box(Vector3(0.14, 1.2, 0.14), silo + Vector3(cos(ang) * 1.0, 0.6, sin(ang) * 1.0), Color("8d969d"), _steel)
	# Office and the manager's car when there is a factory manager.
	var office := Vector3(6.5, 0, 9.8)
	b.box(Vector3(6.0, 2.8, 3.2), office + Vector3(0, 1.4, 0), Color("eceff1"), _paint)
	b.box(Vector3(5.0, 1.0, 0.05), office + Vector3(0, 1.6, 1.62), Color("8fb6d6"), _steel)
	b.box(Vector3(6.3, 0.25, 3.5), office + Vector3(0, 2.9, 0), trim, _paint)
	if running:
		var car := office + Vector3(-5.0, 0, 0.8)
		b.box(Vector3(1.8, 0.7, 3.6), car + Vector3(0, 0.6, 0), Color("212121"), _paint)
		b.box(Vector3(1.6, 0.6, 1.9), car + Vector3(0, 1.2, -0.2), Color("4d6378"), _steel)
