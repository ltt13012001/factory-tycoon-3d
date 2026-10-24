## World positions of the factory lot (metres). The 3D view only; the core
## never needs coordinates.
class_name FactoryLayout
extends RefCounted

const LOT_MIN := Vector2(-24, -16)
const LOT_MAX := Vector2(24, 14)
const ROAD_Z := 19.0
## Machine slots drawn in the hall (the third row opens with the hall expansion).
const MAX_SLOTS := 9

const HALL_MIN := Vector2(-18, -12)
const HALL_MAX := Vector2(6, 5)
const WAREHOUSE_MIN := Vector2(6, -12)
const WAREHOUSE_MAX := Vector2(20, 4)
const DOCK_MIN := Vector2(11, 6)
const DOCK_MAX := Vector2(21, 13)
const OFFICE_MIN := Vector2(-18, 6)
const OFFICE_MAX := Vector2(-9, 13)

## Doorways the workers walk through.
const DOOR_HALL_WAREHOUSE := Vector3(6, 0, -4)
const DOOR_WAREHOUSE_YARD := Vector3(15, 0, 4)
const DOOR_HALL_YARD := Vector3(-6, 0, 5)
const DOOR_HALL_WEST := Vector3(-18, 0, 0)

## Which zones open into which, and through which doorway.
const LINKS := {
	"hall": {"warehouse": DOOR_HALL_WAREHOUSE, "yard": DOOR_HALL_YARD, "side": DOOR_HALL_WEST},
	"warehouse": {"hall": DOOR_HALL_WAREHOUSE, "yard": DOOR_WAREHOUSE_YARD},
	"yard": {"hall": DOOR_HALL_YARD, "warehouse": DOOR_WAREHOUSE_YARD},
	"side": {"hall": DOOR_HALL_WEST},
}

const RAW_DROP := Vector3(11, 0, -7)
const FINISHED_DROP := Vector3(11, 0, 0)
const DOCK_PICKUP := Vector3(16, 0, 11)
const WAREHOUSE_IDLE := Vector3(9, 0, -3)
const OPERATOR_IDLE := Vector3(-17.2, 0, 4)
const OWNER_DESK := Vector3(-13.5, 0, 9.5)
const SCRAP_BIN := Vector3(4.2, 0, 3.6)
const TECH_IDLE := Vector3(-17.2, 0, -11)
const BREAK_IDLE := Vector3(-22.6, 0, -2.2)
const PARKING_MIN := Vector2(-6, 7.5)
const PARKING_MAX := Vector2(8, 13)
const SALES_OFFICE_MIN := Vector2(-23.5, -13)
const SALES_OFFICE_MAX := Vector2(-19, -6)
const BREAK_ROOM_MIN := Vector2(-23.5, -3)
const BREAK_ROOM_MAX := Vector2(-19, 3)
const ANNEX_MIN := Vector2(20.5, -12)
const ANNEX_MAX := Vector2(23.5, 4)
const TRUCK_STOP := Vector3(16, 0, ROAD_Z - 1.5)
const ROAD_WEST := Vector3(-70, 0, ROAD_Z - 1.5)
const ROAD_EAST := Vector3(70, 0, ROAD_Z + 1.5)

const RAW_STACK_ORIGIN := Vector3(13, 0, -11)
const FINISHED_STACK_ORIGIN := Vector3(13, 0, -2.5)
const DOCK_STACK_ORIGIN := Vector3(13, 0, 8)


static func slot_position(slot: int) -> Vector3:
	var col := slot % 3
	var row := slot / 3
	return Vector3(-14 + col * 6.5, 0, -9.5 + row * 5.6)


static func operator_spot(slot: int) -> Vector3:
	return slot_position(slot) + Vector3(0, 0, 1.6)


static func pallet_spot(slot: int) -> Vector3:
	return slot_position(slot) + Vector3(1.9, 0, 0)


static func zone(p: Vector3) -> String:
	if p.z > HALL_MAX.y + 0.5:
		return "yard"
	if p.x < HALL_MIN.x - 0.2:
		return "side"
	return "hall" if p.x < HALL_MAX.x else "warehouse"


## Waypoints from a to b through doorways (a excluded, b included).
static func route(a: Vector3, b: Vector3) -> PackedVector3Array:
	var pts := PackedVector3Array()
	for door in _doors_between(zone(a), zone(b)):
		pts.append(door)
	pts.append(b)
	return pts


## Breadth-first search over LINKS; returns the doorways in walking order.
static func _doors_between(za: String, zb: String) -> Array:
	if za == zb:
		return []
	var prev := {za: ""}
	var queue := [za]
	while not queue.is_empty():
		var z: String = queue.pop_front()
		if z == zb:
			break
		for n in LINKS[z]:
			if not prev.has(n):
				prev[n] = z
				queue.append(n)
	var doors := []
	var cur := zb
	while prev.get(cur, "") != "":
		var from: String = prev[cur]
		doors.push_front(LINKS[from][cur])
		cur = from
	return doors


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
