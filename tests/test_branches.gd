## Every branch location has scenery that builds, and the visit list
## covers them all.
extends TestCase

const BranchThemes := preload("res://scripts/view/branch_themes.gd")


func test_every_branch_builds() -> void:
	var sim := new_sim()
	var ids := BranchView.branch_ids(sim)
	check(ids.has("quang_ninh"), "Hạ Long is a branch")
	check_eq(ids.size(), 11, "domestic and abroad branches")
	var lamp := StandardMaterial3D.new()
	for id in ids:
		var w: BranchWorld = BranchThemes.new()
		w.location_id = id
		w.sim = sim
		w.lamp_material = lamp
		w.window_material = lamp
		var t := Time.get_ticks_msec()
		w.build()
		check(w.get_child_count() >= 4, "%s has scenery" % id)
		print("       %-11s %3d nodes, built in %d ms" % [id, w.get_child_count(), Time.get_ticks_msec() - t])
		w.free()


func test_sea_only_where_expected() -> void:
	var sim := new_sim()
	var w: BranchWorld = BranchThemes.new()
	w.location_id = "quang_ninh"
	w.sim = sim
	check(w.height(0, 0) == 0.0, "factory lot is level")
	check(w.height(0, -60) < BranchWorld.SEA, "the bay is behind the factory")
	check(w.height(0, 80) > 1.0, "hills across the road")
	w.free()
