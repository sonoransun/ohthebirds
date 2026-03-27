# Sugar Glider Adventure — Test Suite

Automated tests for Sugar Glider Adventure. All tests run headlessly via Godot's `--headless` flag — no display required.

## Running Tests

### All tests
```bash
./run_tests.sh
```

If `godot` is not on your PATH, set `GODOT_BIN`:
```bash
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot ./run_tests.sh
```

### Single suite
```bash
godot --path . --headless --script tests/unit/test_game_manager.gd
```

### Expected output
```
╔══════════════════════════════════════════════╗
║   Sugar Glider Adventure — Test Suite        ║
╚══════════════════════════════════════════════╝

── test_game_manager.gd ──
  PASS: test_end_game_transitions_to_game_over
  PASS: test_easy_preset_all_multipliers
  PASS: test_extreme_preset_multipliers
  ...

── test_flythrough.gd ──
  PASS: test_active_climb_drains_energy_and_produces_upward_velocity
  PASS: test_easy_drains_less_energy_than_extreme
  ...

══════════════════════════════════════════════
  ✓ ALL PASSED
  39 passed, 0 failed, 39 total
══════════════════════════════════════════════
```

Exit code `0` = all passed. Exit code `1` = failures present (suitable for CI).

---

## Test Structure

```
tests/
├── base/
│   └── TestBase.gd               Framework: assert methods + test discovery
├── unit/
│   ├── test_game_manager.gd      13 tests: state transitions, scoring, difficulty
│   ├── test_input_manager.gd     10 tests: smoothing, deadzone, normalization
│   ├── test_sugar_glider.gd      13 tests: physics, energy, stun, evasion
│   └── test_difficulty_presets.gd 4 tests: spec for all preset multiplier values
├── integration/
│   └── test_flythrough.gd        5 scenarios: physics simulations over 2–8 seconds
├── examples/
│   ├── example_unit_test.gd      Annotated template for new unit tests
│   └── example_flythrough.gd     Annotated template for physics simulation tests
├── run_all_tests.gd              Main runner (extends SceneTree)
└── README.md                     This file
run_tests.sh                      Shell wrapper (project root)
```

---

## Adding New Tests

1. **Copy a template**: `cp tests/examples/example_unit_test.gd tests/unit/test_my_feature.gd`
2. **Rename the class** (optional — class_name not required, but helps with IDE navigation)
3. **Write test methods**: name them `test_*`
4. **Register the suite** in `tests/run_all_tests.gd` by adding the path to `suite_paths`

### Unit test template
```gdscript
extends TestBase

func setup():
    GameManager.return_to_menu()
    # ... restore state

func teardown():
    GameManager.return_to_menu()
    # ... cleanup

func test_something_specific():
    GameManager.start_new_game()
    GameManager.add_score(100)
    assert_equal(GameManager.get_current_score(), 100)
```

### Fly-through template
```gdscript
extends TestBase

var glider: SugarGlider

func setup():
    GameManager.start_new_game()
    glider = load("res://scenes/player/SugarGlider.tscn").instantiate()
    add_child(glider)
    glider.velocity = Vector2(200.0, 0.0)
    InputManager.set_process(false)

func teardown():
    glider.queue_free()
    InputManager.set_process(true)
    GameManager.return_to_menu()

func test_my_scenario():
    InputManager.input_direction = Vector2(0.0, -1.0)
    InputManager._is_input_active = true
    for _i in 120:  # 2 seconds
        glider._physics_process(1.0 / 60.0)
    assert_lt(glider.current_energy, glider.MAX_ENERGY)
```

---

## Available Assertions

| Method | Description |
|--------|-------------|
| `assert_equal(a, b, msg)` | a == b |
| `assert_not_equal(a, b, msg)` | a != b |
| `assert_true(cond, msg)` | condition is true |
| `assert_false(cond, msg)` | condition is false |
| `assert_approx_equal(a, b, tol, msg)` | \|a - b\| <= tolerance |
| `assert_gt(a, b, msg)` | a > b |
| `assert_lt(a, b, msg)` | a < b |
| `assert_gte(a, b, msg)` | a >= b |
| `assert_null(v, msg)` | v == null |
| `assert_not_null(v, msg)` | v != null |

---

## Key APIs for Tests

### GameManager (autoload)
```gdscript
GameManager.start_new_game()          # Transitions to PLAYING
GameManager.pause_game()              # PLAYING → PAUSED
GameManager.resume_game()             # PAUSED → PLAYING
GameManager.end_game()                # → GAME_OVER
GameManager.return_to_menu()          # → MENU (use in teardown)
GameManager.add_score(points)         # Adds score * score_multiplier
GameManager.update_distance(d)        # Updates distance, triggers difficulty scaling
GameManager.set_difficulty_preset(p)  # DifficultyPreset.EASY/NORMAL/HARD/EXTREME
GameManager.get_current_score()       # -> int
GameManager.get_difficulty_multiplier() # -> float
```

### InputManager (autoload)
```gdscript
InputManager.set_process(false)       # Pause to prevent smoothing interference
InputManager.input_direction = v2     # Set smoothed direction directly
InputManager._is_input_active = bool  # Set active state directly
InputManager.update_input_smoothing(dt) # Advance smoothing manually
InputManager.set_process(true)        # Restore in teardown
```

### SugarGlider (instantiated from scene)
```gdscript
glider.current_energy                 # float, read/write
glider.velocity                       # Vector2, read/write
glider.is_stunned                     # bool, read/write
glider.evasion_mode                   # bool, read/write
glider._physics_process(dt)           # Advance physics one frame
glider.enter_stunned_state(duration)  # Trigger stun
glider.enter_evasion_mode()           # Trigger evasion
glider.exit_evasion_mode()            # Exit evasion
glider.is_gliding()                   # bool
glider.is_low_energy()                # bool
glider.get_debug_info()               # Dictionary with full state
```

---

## Known Headless Warnings

When running headlessly, you'll see harmless warnings:
- `Animation "idle_glide" not found` — SugarGliderSprites.tres has empty animation frames (placeholder)
- GPU particle warnings — no GPU available in headless mode

These warnings don't affect test results. Suppress them by redirecting stderr: `./run_tests.sh 2>/dev/null`

---

## Test Philosophy

- **One concept per test**: a test named `test_energy_drains_during_climb` should only test that — not also test velocity or stun
- **Always reset state**: use `teardown()` to undo anything `setup()` or the test changed
- **Prefer black-box over white-box**: test observable behavior (return values, signals, state flags) not internal implementation
- **Float comparisons**: always use `assert_approx_equal` with a tolerance, never `assert_equal` for floats
- **Isolation**: each test should be runnable in any order without depending on prior tests
