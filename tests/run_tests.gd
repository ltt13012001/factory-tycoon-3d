## Headless test runner:
##   godot --headless --path . --script res://tests/run_tests.gd
## Exits with code 1 if any check fails.
extends SceneTree

const SUITES := [
	"res://tests/test_economy.gd",
	"res://tests/test_production.gd",
	"res://tests/test_orders.gd",
	"res://tests/test_machines.gd",
	"res://tests/test_save.gd",
	"res://tests/test_expansion.gd",
	"res://tests/test_staff.gd",
	"res://tests/test_graphics.gd",
	"res://tests/test_full_loop.gd",
]


var _exit_code := 0


func _initialize() -> void:
	_exit_code = _run_all()


func _process(_delta: float) -> bool:
	quit(_exit_code)
	return true


func _run_all() -> int:
	var total_checks := 0
	var total_failures := 0
	for path in SUITES:
		var suite: TestCase = load(path).new()
		for m in suite.get_method_list():
			var name: String = m.name
			if not name.begins_with("test_"):
				continue
			var before := suite.failures.size()
			suite.call(name)
			var failed := suite.failures.size() - before
			print("%s %s::%s" % ["FAIL" if failed else "ok  ", path.get_file(), name])
			for i in range(before, suite.failures.size()):
				print("       - " + suite.failures[i])
		suite.cleanup()
		total_checks += suite.checks
		total_failures += suite.failures.size()
	print("\n%d checks, %d failures" % [total_checks, total_failures])
	return 1 if total_failures > 0 else 0
