## Shared signals. Simulation events are forwarded here by GameManager
## under the same name, so UI and 3D view subscribe without touching the core.
extends Node

# Simulation events (payload: Dictionary)
signal game_loaded(data: Dictionary)
signal cash_changed(data: Dictionary)
signal material_ordered(data: Dictionary)
signal material_arrived(data: Dictionary)
signal machine_added(data: Dictionary)
signal machine_removed(data: Dictionary)
signal machine_state_changed(data: Dictionary)
signal unit_produced(data: Dictionary)
signal unit_defective(data: Dictionary)
signal employee_hired(data: Dictionary)
signal employee_fired(data: Dictionary)
signal worker_picked_up(data: Dictionary)
signal worker_delivered(data: Dictionary)
signal order_offered(data: Dictionary)
signal order_accepted(data: Dictionary)
signal order_removed(data: Dictionary)
signal order_expired(data: Dictionary)
signal order_shipping(data: Dictionary)
signal order_completed(data: Dictionary)
signal day_ended(data: Dictionary)
signal day_started(data: Dictionary)
signal cash_critical(data: Dictionary)
signal tutorial_advanced(data: Dictionary)

# Presentation events
signal toast(text: String, good: bool)
signal selection_changed(kind: String, id: int)
signal speed_changed(speed: int)
signal build_mode_changed(active: bool)
signal inspect_requested(machine_id: int)
signal report_requested(report: Dictionary)


func forward(name: StringName, data: Dictionary) -> void:
	if has_signal(name):
		emit_signal(name, data)
	else:
		push_warning("EventBus: no signal for event %s" % name)
