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

## Outdoor rest area west of the office (always there), the gate staff
## walk through to and from the street, and the hall aisle where strikers
## sit in.
const REST_MIN := Vector2(-23.6, 4.6)
const REST_MAX := Vector2(-18.6, 13.4)
const STAFF_GATE := Vector3(1, 0, 15.6)
const PICKET_ORIGIN := Vector3(-15.5, 0, 4.3)
const SEAT_HEIGHT := 0.48

## Painted walkways across the yard: from the staff gate between the parked
## cars, up past the office to the hall door, and along the alley between
## the hall and the office to the rest area. [min corner, max corner].
const WALKWAYS := [
	[Vector2(1.4, 10.9), Vector2(2.6, 14.2)],
	[Vector2(-7.6, 10.9), Vector2(2.6, 11.7)],
	[Vector2(-7.6, 5.0), Vector2(-6.4, 11.7)],
	[Vector2(-18.6, 5.15), Vector2(-6.4, 5.85)],
]
## Trees on the pavement outside the fence (x, at z = 15).
const STREET_TREES := [-21.0, -16.5, -9.0, 7.0, 22.0, 33.0]
## Where staff go home to after the shift and come from in the morning:
## the bus stop across the road, or along the pavement out of sight.
const HOMES := [Vector3(-35.2, 0, 22.7), Vector3(36.5, 0, 15.6), Vector3(-40.5, 0, 15.6)]

const RAW_DROP := Vector3(11, 0, -7)
const FINISHED_DROP := Vector3(11, 0, 0)
const DOCK_PICKUP := Vector3(16, 0, 11)
const WAREHOUSE_IDLE := Vector3(9, 0, -3)
const OPERATOR_IDLE := Vector3(-17.2, 0, 4)
const OWNER_DESK := Vector3(-13.5, 0, 9.5)
const SCRAP_BIN := Vector3(4.2, 0, 3.6)
const TECH_IDLE := Vector3(-17.2, 0, -11)
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

## Plots east of the first factory where Xưởng 2, 3 and 4 are built
## (location id -> centre). Each plot is PLOT_SIZE metres.
const PLOTS := {"lot_2": Vector3(52, 0, 0.5), "lot_3": Vector3(78, 0, 0.5), "lot_4": Vector3(104, 0, 0.5)}
const PLOT_SIZE := Vector2(22, 25)

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


## Waypoints from a to b along walkable ground (a excluded, b included).
static func route(a: Vector3, b: Vector3) -> PackedVector3Array:
	return WalkGrid.route(a, b)


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


## Seat i for a resting worker: [position, facing yaw]. The break room's
## chairs and sofa come first once it is built, then the benches outside,
## then standing spots by the water cooler.
static func rest_seat(i: int, break_room: bool) -> Array:
	if break_room:
		if i < 4:
			var ang := i * PI / 2.0
			var c := Vector3(-21.6 + cos(ang) * 1.15, 0, 1.0 + sin(ang) * 1.15)
			return [c, atan2(-cos(ang), -sin(ang)), true]
		if i < 6:
			return [Vector3(-22.75, 0, -2.15 + (i - 4) * 1.1), PI / 2.0, true]
		i -= 6
	if i < 8:
		var row := i / 4
		var x := -22.6 + (i % 4) * 1.0
		return [Vector3(x, 0, 7.4 if row == 0 else 10.4), 0.0 if row == 0 else PI, true]
	i -= 8
	return [Vector3(-22.8 + (i % 5) * 0.9, 0, 12.6 - (i / 5) * 0.8), PI, false]


## Where striker i stands on the front aisle of the hall.
static func picket_spot(i: int) -> Vector3:
	return PICKET_ORIGIN + Vector3((i % 16) * 1.2, 0, -(i / 16) * 0.8)
