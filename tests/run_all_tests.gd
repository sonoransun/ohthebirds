## run_all_tests.gd — Main headless test runner for Sugar Glider Adventure
##
## Run with:
##   godot --path /path/to/birds --headless --script tests/run_all_tests.gd
## Or use the convenience wrapper:
##   ./run_tests.sh
##
## Exit code 0 = all tests passed. Exit code 1 = one or more failures.

extends SceneTree

func _initialize() -> void:
	print("\n╔══════════════════════════════════════════════╗")
	print("║   Sugar Glider Adventure — Test Suite        ║")
	print("╚══════════════════════════════════════════════╝\n")

	var total_passed := 0
	var total_failed := 0

	# Ordered list of test suite scripts to run.
	# Add new test files here when created.
	var suite_paths: Array[String] = [
		"res://tests/unit/test_game_manager.gd",
		"res://tests/unit/test_input_manager.gd",
		"res://tests/unit/test_sugar_glider.gd",
		"res://tests/unit/test_difficulty_presets.gd",
		"res://tests/integration/test_flythrough.gd",
	]

	for script_path in suite_paths:
		var script = load(script_path)
		if not script:
			print("[ERROR] Could not load suite: %s" % script_path)
			total_failed += 1
			continue

		var suite: TestBase = script.new()
		root.add_child(suite)

		print("── %s ──" % script_path.get_file())
		var result: Dictionary = suite.run_all_tests()
		total_passed += result.passed
		total_failed += result.failed
		print("")

		suite.queue_free()

	# Summary
	var status = "✓ ALL PASSED" if total_failed == 0 else "✗ FAILURES DETECTED"
	print("══════════════════════════════════════════════")
	print("  %s" % status)
	print("  %d passed, %d failed, %d total" % [total_passed, total_failed, total_passed + total_failed])
	print("══════════════════════════════════════════════\n")

	quit(1 if total_failed > 0 else 0)
