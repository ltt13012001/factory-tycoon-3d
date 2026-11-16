## Walking routes stay on walkable ground: through doorways and the gate,
## around machines and stock, never through walls or the fence.
extends TestCase


func _spots() -> Array:
	var pts := [
		FactoryLayout.RAW_DROP, FactoryLayout.FINISHED_DROP, FactoryLayout.DOCK_PICKUP,
		FactoryLayout.WAREHOUSE_IDLE, FactoryLayout.OPERATOR_IDLE, FactoryLayout.OWNER_DESK,
		FactoryLayout.TECH_IDLE, FactoryLayout.STAFF_GATE,
	]
	pts.append_array(FactoryLayout.HOMES)
	for slot in FactoryLayout.MAX_SLOTS:
		pts.append(FactoryLayout.operator_spot(slot))
		pts.append(FactoryLayout.pallet_spot(slot) + Vector3(0, 0, 1.0))
		pts.append(FactoryLayout.slot_position(slot) + Vector3(-1.6, 0, 1.2))
	for i in 14:
		pts.append(FactoryLayout.rest_seat(i, i % 2 == 0)[0])
	for i in 20:
		pts.append(FactoryLayout.picket_spot(i))
	return pts


## Every leg between waypoints is clear, except the short first and last
## hop off and onto a spot inside furniture or a machine bay.
func _check_route(a: Vector3, b: Vector3) -> bool:
	var pts := FactoryLayout.route(a, b)
	if pts.is_empty() or pts[pts.size() - 1] != b:
		return false
	var prev := a
	for i in pts.size():
		var p := pts[i]
		var edge := (i == 0 and not WalkGrid.walkable(a)) or (i == pts.size() - 1 and not WalkGrid.walkable(b))
		if edge:
			if prev.distance_to(p) > 3.0:
				return false
		elif not WalkGrid.clear(prev, p):
			return false
		prev = p
	return true


func test_routes_between_all_spots_are_clear() -> void:
	var spots := _spots()
	var bad := 0
	for i in spots.size():
		for j in range(i + 1, spots.size(), 3):
			if not _check_route(spots[i], spots[j]):
				bad += 1
				print("  blocked route ", spots[i], " -> ", spots[j])
	check_eq(bad, 0, "routes through walls or obstacles")


func test_spots_are_reachable() -> void:
	for p in _spots():
		var pts := FactoryLayout.route(FactoryLayout.STAFF_GATE, p)
		check(FactoryLayout.path_length(FactoryLayout.STAFF_GATE, pts) < 120.0, "reachable %s" % p)


func test_walls_and_fence_block() -> void:
	check(not WalkGrid.clear(Vector3(-10, 0, 4), Vector3(-10, 0, 7)), "hall south wall")
	check(not WalkGrid.clear(Vector3(-20, 0, 10), Vector3(-26, 0, 10)), "west fence")
	check(not WalkGrid.clear(Vector3(-14, 0, -7.5), Vector3(-14, 0, -11.5)), "through a machine bay")
	check(WalkGrid.clear(Vector3(-6, 0, 3), Vector3(-6, 0, 7)), "hall door to the yard")
	check(WalkGrid.clear(Vector3(1, 0, 12), Vector3(1, 0, 15.5)), "staff gate")


## Going home leaves through the gate gap, not over the fence.
func test_home_route_uses_the_gate() -> void:
	for home in FactoryLayout.HOMES:
		var pts := FactoryLayout.route(FactoryLayout.operator_spot(0), home)
		var through_gate := false
		var prev := FactoryLayout.operator_spot(0)
		for p in pts:
			if (prev.z - FactoryLayout.LOT_MAX.y) * (p.z - FactoryLayout.LOT_MAX.y) <= 0.0:
				var x := lerpf(prev.x, p.x, (FactoryLayout.LOT_MAX.y - prev.z) / maxf(0.001, p.z - prev.z))
				through_gate = through_gate or (x > -1 and x < 3) or (x > 13 and x < 19)
			prev = p
		check(through_gate, "home %s through a gate" % home)


func test_routes_are_quick() -> void:
	var t := Time.get_ticks_usec()
	var spots := _spots()
	for i in 60:
		FactoryLayout.route(spots[(i * 7) % spots.size()] + Vector3(0.3, 0, 0.1), spots[(i * 11 + 3) % spots.size()])
	var ms := (Time.get_ticks_usec() - t) / 1000.0
	print("  60 routes in %.1f ms" % ms)
	check(ms < 3000.0, "routes take %.1f ms" % ms)


## The factories next door: every spot of a plot can be reached from its
## gate and the routes between them stay clear of walls and machines.
func test_plot_routes_are_clear() -> void:
	for site in FactoryLayout.PLOTS:
		var pts := []
		for name in ["operator_idle", "tech_idle", "warehouse_idle", "finished_drop"]:
			pts.append(FactoryLayout.spot(site, name))
		for slot in FactoryLayout.MAX_SLOTS:
			pts.append(FactoryLayout.operator_spot(slot, site))
			pts.append(FactoryLayout.pallet_spot(slot, site) + Vector3(0, 0, 1.0))
			pts.append(FactoryLayout.slot_position(slot, site) + Vector3(-1.6, 0, 1.2))
		for i in 12:
			pts.append(FactoryLayout.rest_seat(i, false, site)[0])
			pts.append(FactoryLayout.picket_spot(i, site))
		var home := FactoryLayout.site_home(site, 0.3)
		var bad := 0
		for i in pts.size():
			if not _check_route(home, pts[i]):
				bad += 1
				print("  blocked route ", home, " -> ", pts[i])
			if not _check_route(pts[i], pts[(i * 7 + 3) % pts.size()]):
				bad += 1
				print("  blocked route ", pts[i], " -> ", pts[(i * 7 + 3) % pts.size()])
		check_eq(bad, 0, "routes in %s through walls or obstacles" % site)
		var c := FactoryLayout.plot(site)
		check(not WalkGrid.clear(c + Vector3(5, 0, 5), c + Vector3(5, 0, 8)), "hall front wall of %s" % site)
		check(WalkGrid.clear(c + Vector3(-8, 0, 5), c + Vector3(-8, 0, 8)), "hall door of %s" % site)
