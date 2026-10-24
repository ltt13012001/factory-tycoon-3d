## Global balancing numbers. Money is always in cents (int) so the ledger
## matches cash exactly. Time is in simulation ticks.
class_name EconomyConfig
extends Resource

@export_group("Time")
@export var tick_seconds: float = 0.25
@export var ticks_per_day: int = 1440
@export var ticks_per_hour: int = 60
## Clock time at which each game day starts (the shift begins in the morning).
@export var day_start_hour: int = 7

@export_group("Start")
@export var start_cash: int = 100000
@export var start_reputation: int = 50
@export var start_raw_material: int = 100
@export var start_machine_id: String = "basic_injection_molder"
@export var start_operators: int = 1
@export var start_warehouse_workers: int = 1
@export var material_id: String = "plastic_pellets"

@export_group("Factory")
@export var machine_slots: int = 6
@export var raw_capacity: int = 600
@export var finished_capacity: int = 300
@export var rent_per_day: int = 4000

@export_group("Staff")
@export var wage_per_day: int = 4000
@export var hire_fee: int = 10000
@export var worker_names: PackedStringArray = PackedStringArray()
## Ticks for one leg of a warehouse trip (walk to source, then to destination).
@export var haul_leg_ticks: int = 20
@export var haul_finished_batch: int = 10
@export var haul_raw_batch: int = 25
## A worker only fetches from a machine once this many boxes wait (or it is full).
@export var haul_min_boxes: int = 5
## Ticks a technician or the owner needs to walk to a machine.
@export var repair_walk_ticks: int = 20

@export_group("Automation")
## Auto-buy orders a lot when material on hand + incoming drops below this.
@export var auto_buy_threshold: int = 150
@export var auto_buy_lot: int = 250

@export_group("Purchasing")
@export var lot_sizes: PackedInt32Array = PackedInt32Array([100, 250, 500])
@export var shipping_per_lot: int = 2000
@export var delivery_hours: int = 2

@export_group("Sales")
## Unit price = base * (1 - spread/2 + spread * random) * (1 - spread/2 + spread * reputation / 100).
@export var price_random_spread_percent: int = 20
@export var price_reputation_spread_percent: int = 20
@export var max_open_offers: int = 6
@export var customer_truck_ticks: int = 60
@export var reputation_on_time: int = 2
@export var reputation_late: int = -5
@export var reputation_max: int = 100
@export var late_penalty_percent_per_day: int = 10
@export var late_penalty_max_percent: int = 50

@export_group("Cash")
@export var overdraft_limit: int = -50000
@export var overdraft_interest_percent: int = 2
