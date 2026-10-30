## Where people can walk: a fine grid over the factory lot and the
## pavements outside it, with walls, fences, machines, stock, furniture and
## parked cars marked as blocked. Routes are found with A*, pulled tight
## into straight legs and given rounded corners, so workers walk along the
## aisles and through doorways instead of through walls and machines, and
## leave along the pavement after the shift.
class_name WalkGrid
extends RefCounted

const CELL := 0.25
## Grid corner (cell edges sit on whole and quarter metres) and size.
const ORIGIN := Vector2(-41.0, -16.5)
const SIZE := Vector2i(312, 168)  # up to x = 37, z = 25.5
## Half the width of a person: obstacles are grown by this much.
const BODY := 0.25
## Walls are thin and their edges straight, so they are grown a little less
## (the 1 m alleys between buildings stay open).
const WALL := 0.125
const WALL_BODY := 0.2

## Pavements outside the fence: the near one along the lot, the far one past
## the zebra crossing where the bus stop is.
const NEAR_PAVEMENT := Vector2(14.1, 16.0)
const FAR_PAVEMENT := Vector2(22.1, 23.6)
const CROSSING := Vector2(-28.2, -26.4)
## Path costs: people keep to the painted walkways in the yard, cut across
## open concrete only when it saves a lot, and avoid the truck dock.
const YARD_COST := 2.5
const DOCK_COST := 5.0

static var _astar: AStarGrid2D
static var _cache := {}


static func astar() -> AStarGrid2D:
	if _astar == null:
		_build()
	return _astar


## Waypoints from a to b (a excluded, b included) that keep clear of walls
## and obstacles, with rounded corners.
static func route(a: Vector3, b: Vector3) -> PackedVector3Array:
	var g := astar()
	var ca := _free_cell_near(_cell(a))
	var cb := _free_cell_near(_cell(b))
	var key := Vector4i(ca.x, ca.y, cb.x, cb.y)
	var legs: PackedVector3Array
	if _cache.has(key):
		legs = _cache[key]
	else:
		var cells := g.get_id_path(ca, cb)
		legs = _pull_tight(cells)
		if _cache.size() > 600:
			_cache.clear()
		_cache[key] = legs
	var pts := PackedVector3Array()
	# Step out of a blocked spot (a chair, a machine's side) first.
	if not _clear(a, _centre(ca)):
		pts.append(_centre(ca))
	var start := pts[pts.size() - 1] if pts.size() > 0 else a
	var body := PackedVector3Array()
	for p in legs:
		body.append(p)
	# Skip leading points the walker can already go past in a straight line.
	while body.size() > 0 and _clear_on(start, body[1] if body.size() > 1 else b):
		body.remove_at(0)
	# Go straight to b from the last point that can see it.
	while body.size() > 1 and _clear_on(body[body.size() - 2], b):
		body.remove_at(body.size() - 1)
	if body.size() > 0 and body[body.size() - 1].distance_to(b) < CELL:
		var before := body[body.size() - 2] if body.size() > 1 else start
		if _clear_on(before, b):
			body.remove_at(body.size() - 1)
	pts.append_array(body)
	pts.append(b)
	return _round_corners(a, pts)


## True when the straight line a-b crosses only walkable cells.
static func clear(a: Vector3, b: Vector3) -> bool:
	astar()
	return _clear(a, b)


static func walkable(p: Vector3) -> bool:
	var c := _cell(p)
	return astar().is_in_boundsv(c) and not _astar.is_point_solid(c)


static func _cell(p: Vector3) -> Vector2i:
	return Vector2i(floori((p.x - ORIGIN.x) / CELL), floori((p.z - ORIGIN.y) / CELL))


static func _centre(c: Vector2i) -> Vector3:
	return Vector3(ORIGIN.x + (c.x + 0.5) * CELL, 0, ORIGIN.y + (c.y + 0.5) * CELL)


static func _solid(c: Vector2i) -> bool:
	return not _astar.is_in_boundsv(c) or _astar.is_point_solid(c)


## Nearest walkable cell, searching outward in rings.
static func _free_cell_near(c: Vector2i) -> Vector2i:
	c = c.clamp(Vector2i.ZERO, SIZE - Vector2i.ONE)
	if not _solid(c):
		return c
	for r in range(1, 24):
		var best := Vector2i(-1, -1)
		var best_d := INF
		for dx in range(-r, r + 1):
			for dy in [-r, r]:
				for q in [Vector2i(dx, dy), Vector2i(dy, dx)]:
					var n: Vector2i = c + q
					if not _solid(n) and Vector2(q).length() < best_d:
						best_d = Vector2(q).length()
						best = n
		if best.x >= 0:
			return best
	return c


## Walks every cell the segment a-b passes through (a grid traversal, so a
## part of a clear line is always clear too; passing a corner needs both
## cells beside it free).
static func _clear(a: Vector3, b: Vector3, max_cost := INF) -> bool:
	var p := Vector2((a.x - ORIGIN.x) / CELL, (a.z - ORIGIN.y) / CELL)
	var q := Vector2((b.x - ORIGIN.x) / CELL, (b.z - ORIGIN.y) / CELL)
	var c := Vector2i(floori(p.x), floori(p.y))
	var end := Vector2i(floori(q.x), floori(q.y))
	var d := q - p
	var step := Vector2i(signi(int(signf(d.x))), signi(int(signf(d.y))))
	var t_delta := Vector2(INF if d.x == 0.0 else absf(1.0 / d.x), INF if d.y == 0.0 else absf(1.0 / d.y))
	var t_max := Vector2(
		INF if d.x == 0.0 else ((c.x + (1 if d.x > 0.0 else 0)) - p.x) / d.x,
		INF if d.y == 0.0 else ((c.y + (1 if d.y > 0.0 else 0)) - p.y) / d.y)
	var guard := 0
	while true:
		if _solid(c) or _astar.get_point_weight_scale(c) > max_cost:
			return false
		if c == end or guard > 4000:
			return true
		guard += 1
		if absf(t_max.x - t_max.y) < 1e-4:
			# Through a corner: both cells beside it must be free too.
			if _solid(Vector2i(c.x + step.x, c.y)) or _solid(Vector2i(c.x, c.y + step.y)):
				return false
			c += step
			t_max += t_delta
		elif t_max.x < t_max.y:
			c.x += step.x
			t_max.x += t_delta.x
		else:
			c.y += step.y
			t_max.y += t_delta.y
	return true


## Clear, and never over ground costlier than both ends (so a shortcut
## does not leave a walkway to cut across the yard).
static func _clear_on(a: Vector3, b: Vector3) -> bool:
	return _clear(a, b, maxf(_cost(a), _cost(b)) + 0.01)


static func _cost(p: Vector3) -> float:
	var c := _cell(p).clamp(Vector2i.ZERO, SIZE - Vector2i.ONE)
	return _astar.get_point_weight_scale(c)


## Keeps only the turning points: from each point, go as far ahead as a
## straight line stays clear.
static func _pull_tight(cells: Array[Vector2i]) -> PackedVector3Array:
	var out := PackedVector3Array()
	if cells.is_empty():
		return out
	var pts: Array[Vector3] = []
	for c in cells:
		pts.append(_centre(c))
	out.append(pts[0])
	var anchor := 0
	while anchor < pts.size() - 1:
		var next := anchor + 1
		while next + 1 < pts.size() and _clear_on(pts[anchor], pts[next + 1]):
			next += 1
		out.append(pts[next])
		anchor = next
	return out


## Replaces each sharp corner with a short curve where the shortcut is clear.
static func _round_corners(start: Vector3, pts: PackedVector3Array) -> PackedVector3Array:
	if pts.size() < 2:
		return pts
	var out := PackedVector3Array()
	var prev := start
	for i in pts.size():
		var p := pts[i]
		if i == pts.size() - 1:
			out.append(p)
			break
		var nxt := pts[i + 1]
		var r := minf(0.9, minf(prev.distance_to(p), p.distance_to(nxt)) * 0.45)
		var a := p + (prev - p).normalized() * r
		var b := p + (nxt - p).normalized() * r
		var curve := PackedVector3Array()
		if r >= 0.15:
			for k in 5:
				var t := k / 4.0
				curve.append(a.lerp(p, t).lerp(p.lerp(b, t), t))
			for k in 4:
				if not _clear(curve[k], curve[k + 1]):
					curve.clear()
					break
		if curve.is_empty():
			out.append(p)
		else:
			out.append_array(curve)
		prev = p
	return out


# --- Map ------------------------------------------------------------------------

static func _build() -> void:
	_astar = AStarGrid2D.new()
	_astar.region = Rect2i(Vector2i.ZERO, SIZE)
	_astar.cell_size = Vector2(CELL, CELL)
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.update()
	_astar.fill_solid_region(_astar.region, true)
	_cache.clear()
	# Walkable ground: the lot, the pavements, the driveways and the crossing.
	var lot_a := FactoryLayout.LOT_MIN
	var lot_b := FactoryLayout.LOT_MAX
	_open(lot_a, lot_b)
	_open(Vector2(ORIGIN.x, NEAR_PAVEMENT.x), Vector2(ORIGIN.x + SIZE.x * CELL, NEAR_PAVEMENT.y))
	_open(Vector2(ORIGIN.x, FAR_PAVEMENT.x), Vector2(ORIGIN.x + SIZE.x * CELL, FAR_PAVEMENT.y))
	_open(Vector2(CROSSING.x, NEAR_PAVEMENT.x), Vector2(CROSSING.y, FAR_PAVEMENT.y))
	# Fence with the two driveway gaps
	_wall_line(Vector2(lot_a.x, lot_a.y), Vector2(lot_b.x, lot_a.y), [])
	_wall_line(Vector2(lot_a.x, lot_a.y), Vector2(lot_a.x, lot_b.y), [])
	_wall_line(Vector2(lot_b.x, lot_a.y), Vector2(lot_b.x, lot_b.y), [])
	_wall_line(Vector2(lot_a.x, lot_b.y), Vector2(lot_b.x, lot_b.y), [Vector2(-1, 3), Vector2(13, 19)])
	# Buildings: hall, warehouse, office and the two side rooms
	_room(FactoryLayout.HALL_MIN, FactoryLayout.HALL_MAX, {"e": [Vector2(-8, 0)], "s": [Vector2(-8, -4)], "w": [Vector2(-1.5, 1.5)]})
	_room(FactoryLayout.WAREHOUSE_MIN, FactoryLayout.WAREHOUSE_MAX, {"s": [Vector2(13, 17)], "w": [Vector2(-8, 0)]})
	_room(FactoryLayout.OFFICE_MIN, FactoryLayout.OFFICE_MAX, {"n": [Vector2(-15, -12)]})
	_room(FactoryLayout.SALES_OFFICE_MIN, FactoryLayout.SALES_OFFICE_MAX, {"e": [Vector2(-10.8, -8.8)]})
	_room(FactoryLayout.BREAK_ROOM_MIN, FactoryLayout.BREAK_ROOM_MAX, {"e": [Vector2(-1.5, 1.5)]})
	_room(FactoryLayout.ANNEX_MIN, FactoryLayout.ANNEX_MAX, {})
	# Machine bays (every slot, built or not)
	for slot in FactoryLayout.MAX_SLOTS:
		var p := FactoryLayout.slot_position(slot)
		_block(Vector2(p.x - 1.5, p.z - 1.05), Vector2(p.x + 2.65, p.z + 1.05))
	# Hall: workbench, compressor and tank by the west wall, scrap skip
	_block(Vector2(-18, -7.2), Vector2(-17.1, -1.9))
	_block(Vector2(3.6, 3.0), Vector2(4.8, 4.2))
	# Warehouse: forklift, raw and finished stock
	_block(Vector2(7.4, -11.5), Vector2(9.0, -9.3))
	_block(Vector2(12.4, -11.7), Vector2(19.5, -9.0))
	_block(Vector2(12.4, -3.1), Vector2(19.5, 0.7))
	# Dock: bags waiting for the truck and the pallet truck
	_block(Vector2(12.5, 7.5), Vector2(19.0, 9.6))
	_block(Vector2(19.4, 8.5), Vector2(20.3, 9.9))
	# Office furniture
	_block(Vector2(-14.5, 10.0), Vector2(-12.5, 11.0))
	_block(Vector2(-17.85, 7.6), Vector2(-17.0, 9.6))
	_block(Vector2(-11.3, 12.35), Vector2(-9.5, 12.85))
	_block(Vector2(-17.5, 12.25), Vector2(-16.5, 12.75))
	# Rest area table, break room table and machines, sales office desks
	_block(Vector2(-23.2, 8.2), Vector2(-19.0, 9.6))
	_block(Vector2(-22.4, 0.2), Vector2(-20.8, 1.8))
	_block(Vector2(-23.4, 2.05), Vector2(-22.6, 2.75))
	_block(Vector2(-23.5, -2.7), Vector2(-22.5, -0.5))
	_block(Vector2(-23.0, -12.2), Vector2(-21.4, -11.0))
	_block(Vector2(-23.0, -9.4), Vector2(-21.4, -8.2))
	# Car park: parked cars, the motorbike, light pole and canopy posts
	for i in 4:
		var x := FactoryLayout.PARKING_MIN.x + 2.0 + i * 4.0
		_block(Vector2(x - 1.0, 7.4), Vector2(x + 1.0, 10.6))
	_block(Vector2(6.2, 11.3), Vector2(6.6, 13.1))
	for x in range(int(FactoryLayout.PARKING_MIN.x) + 1, int(FactoryLayout.PARKING_MAX.x), 4):
		_block(Vector2(x - 0.1, 7.9), Vector2(x + 0.1, 8.1))
		_block(Vector2(x - 0.1, 11.9), Vector2(x + 0.1, 12.1))
	_block(Vector2(7.6, 12.5), Vector2(7.8, 12.7))
	# Flower beds, guard booth, flagpole, street trees and lamps
	_block(Vector2(-17.5, 13.2), Vector2(-9.5, 14.0))
	_block(Vector2(5.0, 13.2), Vector2(12.0, 14.0))
	_block(Vector2(-3.4, 5.4), Vector2(-1.4, 6.2))
	_block(Vector2(8.8, 12.1), Vector2(10.4, 13.7))
	_block(Vector2(7.5, 12.9), Vector2(7.7, 13.1))
	for x in FactoryLayout.STREET_TREES:
		_block(Vector2(x - 0.25, 15.0 - 0.25), Vector2(x + 0.25, 15.0 + 0.25))
	for x in range(-84, 85, 14):
		if absf(x - 16) >= 4:
			_block(Vector2(x - 0.15, 15.1 - 0.15), Vector2(x + 0.15, 15.1 + 0.15))
	_block(Vector2(12.2, 14.9), Vector2(12.6, 15.5))  # barrier post
	_block(Vector2(-37.6, 23.6), Vector2(-34.4, 24.0))  # bus shelter
	_set_costs()


## Open yard costs more than floors, pavements and walkways; the dock more.
static func _set_costs() -> void:
	var rooms := [
		[FactoryLayout.HALL_MIN, FactoryLayout.HALL_MAX], [FactoryLayout.WAREHOUSE_MIN, FactoryLayout.WAREHOUSE_MAX],
		[FactoryLayout.OFFICE_MIN, FactoryLayout.OFFICE_MAX], [FactoryLayout.REST_MIN, FactoryLayout.REST_MAX],
		[FactoryLayout.SALES_OFFICE_MIN, FactoryLayout.SALES_OFFICE_MAX], [FactoryLayout.BREAK_ROOM_MIN, FactoryLayout.BREAK_ROOM_MAX],
	]
	var lot := _cells(FactoryLayout.LOT_MIN, FactoryLayout.LOT_MAX)
	for y in range(lot.position.y, lot.end.y):
		for x in range(lot.position.x, lot.end.x):
			var c := Vector2i(x, y)
			var p := _centre(c)
			var cost := YARD_COST
			for r in rooms:
				if p.x > r[0].x and p.x < r[1].x and p.z > r[0].y and p.z < r[1].y:
					cost = 1.0
					break
			if p.x > FactoryLayout.DOCK_MIN.x - 1.0 and p.z > FactoryLayout.WAREHOUSE_MAX.y:
				cost = DOCK_COST
			_astar.set_point_weight_scale(c, cost)
	for w in FactoryLayout.WALKWAYS:
		var r := _cells(w[0], w[1])
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				_astar.set_point_weight_scale(Vector2i(x, y), 1.0)


static func _cells(a: Vector2, b: Vector2) -> Rect2i:
	var from := Vector2i(ceili((a.x - ORIGIN.x) / CELL - 0.5), ceili((a.y - ORIGIN.y) / CELL - 0.5))
	var to := Vector2i(floori((b.x - ORIGIN.x) / CELL - 0.5), floori((b.y - ORIGIN.y) / CELL - 0.5))
	if to.x < from.x or to.y < from.y:
		return Rect2i()
	return Rect2i(from, to - from + Vector2i.ONE).intersection(_astar.region)


static func _open(a: Vector2, b: Vector2) -> void:
	var r := _cells(a, b)
	if r.has_area():
		_astar.fill_solid_region(r, false)


## Blocks a rectangle grown by a body's half width.
static func _block(a: Vector2, b: Vector2, grow := BODY) -> void:
	var r := _cells(a - Vector2(grow, grow), b + Vector2(grow, grow))
	if r.has_area():
		_astar.fill_solid_region(r, true)


## A straight wall from a to b (along x or z) with open gaps (ranges along it).
static func _wall_line(a: Vector2, b: Vector2, gaps: Array) -> void:
	var horizontal := absf(b.x - a.x) > absf(b.y - a.y)
	var from := minf(a.x, b.x) if horizontal else minf(a.y, b.y)
	var to := maxf(a.x, b.x) if horizontal else maxf(a.y, b.y)
	var cuts := gaps.duplicate()
	cuts.sort_custom(func(p, q): return p.x < q.x)
	cuts.append(Vector2(to, to))
	var cursor := from
	for g in cuts:
		if g.x > cursor:
			if horizontal:
				_block(Vector2(cursor, a.y - WALL), Vector2(g.x, a.y + WALL), WALL_BODY)
			else:
				_block(Vector2(a.x - WALL, cursor), Vector2(a.x + WALL, g.x), WALL_BODY)
		cursor = maxf(cursor, g.y)


## The four walls of a room with doorways: {side: [Vector2(from, to), ...]}.
static func _room(a: Vector2, b: Vector2, doors: Dictionary) -> void:
	_wall_line(Vector2(a.x, a.y), Vector2(b.x, a.y), doors.get("n", []))
	_wall_line(Vector2(a.x, b.y), Vector2(b.x, b.y), doors.get("s", []))
	_wall_line(Vector2(a.x, a.y), Vector2(a.x, b.y), doors.get("w", []))
	_wall_line(Vector2(b.x, a.y), Vector2(b.x, b.y), doors.get("e", []))
