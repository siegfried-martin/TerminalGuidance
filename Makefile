# Missile Rider — everything you need from the command line.
# The Godot editor is a viewer of last resort; nothing here requires it.

GODOT ?= godot
SCENE ?= res://scenes/arena.tscn
SHOTS ?= .shots

.DEFAULT_GOAL := help
.PHONY: help run fly sandbox check import assets shot editor apiref clean

help:  ## Show this help
	@grep -E '^[a-z-]+:.*?## ' $(MAKEFILE_LIST) | awk -F':.*?## ' '{printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'

# Every target that a HUMAN plays goes through tools/play.sh, which turns the
# touchpad's "disable while typing" off for the lifetime of the game and puts it
# back after. Holding the throttle otherwise mutes the trackpad, so you can steer or
# accelerate and never both. `check` and `shot` do not need it — the gate reads no
# devices and the capture harnesses take their own controls (ADR 0031).
run:  ## Play the combat arena in a window (SCENE=... to override)
	@tools/play.sh $(GODOT) --scene $(SCENE)

# The travel POC is a separate scene on purpose: it carries the helm and nothing
# else, because only the pilot matters there. Two scenes means two commands.
fly:  ## Play the exploration POC — systems, the corridor, the road, docking
	@tools/play.sh $(GODOT) --scene res://scenes/exploration.tscn

sandbox:  ## Open the asset harness with the debug fly-cam
	@tools/play.sh $(GODOT) --scene res://scenes/sandbox.tscn

check: import  ## Headless gate: compiles, Godot-3 API lint, tuning keys, assets, scene build
	@# `timeout` is a watchdog, not a nicety: if the runner script itself fails to
	@# parse, its scene root has no script, nothing calls quit(), and the engine
	@# idles forever instead of failing. Depending on `import` keeps the global
	@# class cache fresh so a newly added `class_name` resolves.
	@timeout $${CHECK_TIMEOUT:-180} $(GODOT) --headless --scene res://tools/tests/test_runner.tscn; \
		status=$$?; \
		if [ $$status -eq 124 ]; then echo "  FAIL  check timed out after $${CHECK_TIMEOUT:-180}s"; fi; \
		exit $$status

import:  ## Re-import assets (run after adding or regenerating a file in assets/)
	@$(GODOT) --headless --import >/dev/null && echo "assets imported"

assets:  ## Regenerate the generated placeholder assets, then import them
	@cd tools && python3 gen_probe_obj.py && python3 gen_carrier_obj.py \
		&& python3 gen_road_modules.py
	@python3 tools/gen_textures.py
	@$(MAKE) --no-print-directory import

shot:  ## Render N frames to $(SHOTS)/ so a change can be eyeballed without playing
	@mkdir -p $(SHOTS) && rm -f $(SHOTS)/*.png
	@$(GODOT) --write-movie $(SHOTS)/frame.png --quit-after $${FRAMES:-20} --fixed-fps 10 \
		--scene $(SCENE) 2>&1 | grep -E "frames at|ERROR" || true
	@ls $(SHOTS)/*.png | tail -1

editor:  ## Open the Godot editor (viewing and debugging only — do not author here)
	$(GODOT) --editor

apiref:  ## Dump this exact engine build's class reference to .apiref/ (never guess a 4.x API)
	@mkdir -p .apiref && $(GODOT) --headless --doctool .apiref --no-docbase >/dev/null 2>&1; \
		echo "class reference in .apiref/doc/classes/ ($$(ls .apiref/doc/classes 2>/dev/null | wc -l) files)"

clean:  ## Remove local caches and render output
	rm -rf .godot $(SHOTS) .apiref
