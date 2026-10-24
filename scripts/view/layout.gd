## World positions of the factory lot (metres). The 3D view only; the core
## never needs coordinates.
class_name FactoryLayout
extends RefCounted

const LOT_MIN := Vector2(-24, -16)
const LOT_MAX := Vector2(24, 14)
const ROAD_Z := 19.0

const HALL_MIN := Vector2(-18, -12)
const HALL_MAX := Vector2(6, 4)
const WAREHOUSE_MIN := Vector2(6, -12)
const WAREHOUSE_MAX := Vector2(20, 4)
const DOCK_MIN := Vector2(11, 6)
const DOCK_MAX := Vector2(21, 13)
const OFFICE_MIN := Vector2(-18, 6)
const OFFICE_MAX := Vector2(-9, 13)

## Doorways the workers walk through.
const DOOR_HALL_WAREHOUSE := Vector3(6, 0, -4)
const DOOR_WAREHOUSE_YARD := Vector3(15, 0, 4)
const DOOR_HALL_YARD := Vector3(-6, 0, 4)

const RAW_DROP := Vector3(11, 0, -7)
const FINISHED_DROP := Vector3(11, 0, 0)
const DOCK_PICKUP := Vector3(16, 0, 11)
const WAREHOUSE_IDLE := Vector3(9, 0, -3)
const OPERATOR_IDLE := Vector3(-6, 0, 2.5)
const OWNER_DESK := Vector3(-13.5, 0, 9.5)
const SCRAP_BIN := Vector3(3.5, 0, 2.5)
const TRUCK_STOP := Vector3(16, 0, ROAD_Z - 1.5)
const ROAD_WEST := Vector3(-70, 0, ROAD_Z - 1.5)
const ROAD_EAST := Vector3(70, 0, ROAD_Z + 1.5)

const RAW_STACK_ORIGIN := Vector3(13, 0, -11)
const FINISHED_STACK_ORIGIN := Vector3(13, 0, -2.5)
const DOCK_STACK_ORIGIN := Vector3(13, 0, 8)


static func slot_position(slot: int) -> Vector3:
	var col := slot % 3
	var row := slot / 3
	return Vector3(-14 + col * 6.5, 0, -7.5 + row * 7)


static func operator_spot(slot: int) -> Vector3:
	return slot_position(slot) + Vector3(0, 0, 1.6)


static func pallet_spot(slot: int) -> Vector3:
	return slot_position(slot) + Vector3(1.9, 0, 0)


static func zone(p: Vector3) -> String:
	if p.z > HALL_MAX.y + 0.5:
		return "yard"
	return "hall" if p.x < HALL_MAX.x else "warehouse"


## Waypoints from a to b through doorways (a excluded, b included).
static func route(a: Vector3, b: Vector3) -> PackedVector3Array:
	var za := zone(a)
	var zb := zone(b)
	var pts := PackedVector3Array()
	if za != zb:
		var key := za + ">" + zb
		match key:
			"hall>warehouse", "warehouse>hall":
				pts.append(DOOR_HALL_WAREHOUSE)
			"warehouse>yard", "yard>warehouse":
				pts.append(DOOR_WAREHOUSE_YARD)
			"hall>yard", "yard>hall":
				pts.append(DOOR_HALL_YARD)
	pts.append(b)
	return pts


static func path_length(start: Vector3, pts: PackedVector3Array) -> float:
	var total := 0.0
	var prev := start
	for p in pts:
		total += prev.distance_to(p)
		prev = p
	return total


## Point at fraction t (0..1) along start -> pts.
static func point_along(start: Vector3, pts: PackedVector3Array, t: float) -> Vector3:
	var total := path_length(start, pts)
	if total <= 0.001:
		return pts[pts.size() - 1] if pts.size() > 0 else start
	var want := clampf(t, 0.0, 1.0) * total
	var prev := start
	for p in pts:
		var seg := prev.distance_to(p)
		if want <= seg:
			return prev.lerp(p, want / maxf(seg, 0.001))
		want -= seg
		prev = p
	return prev
