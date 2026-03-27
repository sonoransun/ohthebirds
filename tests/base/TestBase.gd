## TestBase.gd — Lightweight GDScript test framework for Sugar Glider Adventure
##
## Usage: extend this class, name methods "test_*", override setup()/teardown().
## Call run_all_tests() to discover and run all test methods automatically.
##
## Example:
##   class_name MyTests extends TestBase
##   func setup(): GameManager.return_to_menu()
##   func test_something(): assert_true(1 + 1 == 2, "basic math works")

class_name TestBase
extends Node

# ---- Internal tracking (one set per test method) ----
var _total_passed: int = 0
var _total_failed: int = 0
var _current_test_name: String = ""
var _current_test_assertions: int = 0
var _current_test_failed: bool = false
var _current_failures: Array[String] = []

# ============================================================
# ASSERTIONS
# Add as many assert calls as needed inside a test_ method.
# All failures are collected; execution continues after each one.
# A test passes only if it makes at least one assertion AND none fail.
# ============================================================

## Asserts that actual == expected (using ==).
func assert_equal(actual, expected, msg: String = "") -> void:
	_current_test_assertions += 1
	if actual != expected:
		_record_failure("expected [%s] but got [%s]%s" % [
			str(expected), str(actual), " — " + msg if msg else ""
		])

## Asserts that actual != expected.
func assert_not_equal(actual, expected, msg: String = "") -> void:
	_current_test_assertions += 1
	if actual == expected:
		_record_failure("expected values to differ, both were [%s]%s" % [
			str(actual), " — " + msg if msg else ""
		])

## Asserts that condition is true.
func assert_true(condition: bool, msg: String = "") -> void:
	_current_test_assertions += 1
	if not condition:
		_record_failure("condition was false%s" % (" — " + msg if msg else ""))

## Asserts that condition is false.
func assert_false(condition: bool, msg: String = "") -> void:
	_current_test_assertions += 1
	if condition:
		_record_failure("condition was true%s" % (" — " + msg if msg else ""))

## Asserts that |actual - expected| <= tolerance (default 0.001).
func assert_approx_equal(actual: float, expected: float, tolerance: float = 0.001, msg: String = "") -> void:
	_current_test_assertions += 1
	var diff = abs(actual - expected)
	if diff > tolerance:
		_record_failure("|%.4f - %.4f| = %.4f > tolerance %.4f%s" % [
			actual, expected, diff, tolerance, " — " + msg if msg else ""
		])

## Asserts that actual > than.
func assert_gt(actual: float, than: float, msg: String = "") -> void:
	_current_test_assertions += 1
	if actual <= than:
		_record_failure("%.4f is not > %.4f%s" % [actual, than, " — " + msg if msg else ""])

## Asserts that actual < than.
func assert_lt(actual: float, than: float, msg: String = "") -> void:
	_current_test_assertions += 1
	if actual >= than:
		_record_failure("%.4f is not < %.4f%s" % [actual, than, " — " + msg if msg else ""])

## Asserts that actual >= than.
func assert_gte(actual: float, than: float, msg: String = "") -> void:
	_current_test_assertions += 1
	if actual < than:
		_record_failure("%.4f is not >= %.4f%s" % [actual, than, " — " + msg if msg else ""])

## Asserts that value is null.
func assert_null(value, msg: String = "") -> void:
	_current_test_assertions += 1
	if value != null:
		_record_failure("expected null, got [%s]%s" % [str(value), " — " + msg if msg else ""])

## Asserts that value is not null.
func assert_not_null(value, msg: String = "") -> void:
	_current_test_assertions += 1
	if value == null:
		_record_failure("expected non-null value%s" % (" — " + msg if msg else ""))

# ============================================================
# LIFECYCLE HOOKS — override in subclasses
# setup() runs before each test method
# teardown() runs after each test method
# ============================================================

func setup() -> void:
	pass

func teardown() -> void:
	pass

# ============================================================
# TEST RUNNER
# ============================================================

## Discovers all test_ methods, runs them, returns {passed, failed, total}.
## Prints PASS/FAIL for each test method to stdout.
func run_all_tests() -> Dictionary:
	# Collect all test method names, sorted alphabetically for consistent ordering
	var method_names: Array[String] = []
	for method in get_method_list():
		if method["name"].begins_with("test_"):
			method_names.append(method["name"])
	method_names.sort()

	for method_name in method_names:
		_current_test_name = method_name
		_current_test_assertions = 0
		_current_test_failed = false
		_current_failures.clear()

		setup()
		call(method_name)
		teardown()

		if _current_test_assertions == 0:
			_total_failed += 1
			print("  FAIL: %s — no assertions made (empty test)" % method_name)
		elif _current_test_failed:
			_total_failed += 1
			for failure_msg in _current_failures:
				print("  FAIL: %s — %s" % [method_name, failure_msg])
		else:
			_total_passed += 1
			print("  PASS: %s" % method_name)

	return {
		"passed": _total_passed,
		"failed": _total_failed,
		"total": _total_passed + _total_failed
	}

# ---- Internal ----
func _record_failure(message: String) -> void:
	_current_test_failed = true
	_current_failures.append(message)
