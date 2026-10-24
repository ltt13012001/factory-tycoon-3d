## All mutable game data. Holds only ints, strings, bools, arrays and
## dictionaries so it round-trips through JSON without loss.
class_name GameState
extends RefCounted

const FIELDS := [
	"tick", "world_seed", "rng_state", "cash", "reputation",
	"raw", "dock", "finished", "raw_value", "scrap_total",
	"machines", "employees", "orders", "purchases",
	"order_spawn_acc", "power_accrued", "day_start_cash", "day_stats",
	"ledger", "reports", "tutorial_step", "next_id", "name_index",
	"total_revenue", "machines_bought",
]

var tick: int = 0
var world_seed: int = 0
var rng_state: String = "0"
var cash: int = 0
var reputation: int = 0
## Material units in the raw store / waiting at the dock.
var raw: int = 0
var dock: int = 0
## Good boxes in the finished store.
var finished: int = 0
## Book value (cents) of every material unit owned: store + dock + carried.
var raw_value: int = 0
var scrap_total: int = 0
## {id, def_id, slot, in_cycle, ticks_left, buffer, status, operator_id, produced, defects}
var machines: Array = []
## {id, name, role, machine_id, job}; job = {} or {kind, phase, ticks_left, machine_id, qty}
var employees: Array = []
## {id, customer, qty, unit_price, deadline_days, offered_tick, expire_tick,
##  accepted_tick, deadline_tick, status, ship_ticks_left, paid_tick, penalty}
var orders: Array = []
## {id, qty, cost, arrive_tick}
var purchases: Array = []
var order_spawn_acc: int = 0
var power_accrued: int = 0
var day_start_cash: int = 0
var day_stats: Dictionary = {}
## Cash movements of the current day: {tick, category, amount, note}
var ledger: Array = []
## Closed daily reports, newest last.
var reports: Array = []
var tutorial_step: int = 0
var next_id: int = 1
var name_index: int = 0
var total_revenue: int = 0
var machines_bought: int = 0


func take_id() -> int:
	next_id += 1
	return next_id - 1


func to_dict() -> Dictionary:
	var d := {}
	for f in FIELDS:
		var v = get(f)
		d[f] = v.duplicate(true) if (v is Array or v is Dictionary) else v
	return d


func from_dict(d: Dictionary) -> void:
	for f in FIELDS:
		if d.has(f):
			var v = normalize(d[f])
			set(f, v.duplicate(true) if (v is Array or v is Dictionary) else v)


## JSON turns every number into a float. State never stores floats,
## so whole-number floats are converted back to int.
static func normalize(v):
	if v is float and is_equal_approx(v, roundf(v)):
		return int(v)
	if v is Array:
		var a := []
		for x in v:
			a.append(normalize(x))
		return a
	if v is Dictionary:
		var out := {}
		for k in v:
			out[k] = normalize(v[k])
		return out
	return v


func find_by_id(list: Array, id: int) -> Dictionary:
	for e in list:
		if e.id == id:
			return e
	return {}
