# Offline Lua 5.1 regressions

Run from any directory, with Python and Lupa installed:

```text
python -m pip install -r unit-tests/offline/requirements.txt
python unit-tests/offline/run_tests.py
python unit-tests/offline/run_tests.py --target sources --scenario 00_smoke.lua
```

The default runs every scenario against both the source concatenation (using the
build script's exact file order) and the committed compiled script, each in a fresh
Lua 5.1 runtime. Regenerate the compiled script before the final run after source edits.

Individual source files are not independent chunks: existing do/end blocks span
file boundaries. The runner therefore compiles the complete concatenation.

The DCS/MIST doubles intentionally model only the contracts needed by each test.
They do not establish in-game FPS improvements, radar physics, engine event timing,
or complete compatibility with DCS. Existing mission-based tests remain necessary.
Operation-count assertions test eliminated work without unstable timing thresholds.

Add independent regression scenarios under scenarios/. Keep each scenario isolated;
never depend on state left by another scenario.

