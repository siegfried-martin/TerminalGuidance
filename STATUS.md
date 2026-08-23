# STATUS

*Updated 2026-08-23.*

## Where the build is

Bootstrap complete: the toolchain is proven end to end from the command line, with
no use of the Godot editor GUI at any point. **No combat POC code exists yet.**

### What works

| Thing | State |
|---|---|
| Godot 4.7.2 project, runs windowed and headless | working |
| `tuning.json` hot reload (save the file, the running game changes) | working |
| `Tuning` autoload with typed getters and loud missing-key errors | working |
| Input bindings from `data/input_map.json` (no editor Input Map tab) | working |
| Debug HUD with pluggable readout rows + tuning status line | working |
| Gray-box arena: 7³ marker lattice via one MultiMesh, rebuilt on reload | working |
| Debug fly-cam (RMB look, WASD/QE, Shift boost) | working |
| Asset pipeline: `.obj` model + `.png` texture, generated → imported → rendered | working |
| `make check`: 71 headless assertions, exit code gated | working |
| Godot-3 API linter over all scripts, data-driven denylist | working |
| `make shot`: render frames to PNG from the CLI for visual verification | working |
| `make apiref`: this exact build's 771-class reference for API grounding | working |
| `DESIGN.md` — distilled thesis, Target Experience verbatim | written |
| `decisions/` — 31 seed ADRs, indexed, each with a *What this forbids* section | written |

### Deliberately not built yet

Everything in the combat POC: missile, turret, cooldown, blockers, enemy, the
interrupt, mothership autopilot. Build order is in
`docs/COMBAT_POC_IMPLEMENTATION.md` §Build Order — the sandbox above corresponds to
step 1 and step 2 (scaffold, and the tuning/HUD instrument that everything else is
played through).

## Next

Scaffold is complete. The POC starts at step 3 of
`docs/COMBAT_POC_IMPLEMENTATION.md` §Build Order.

1. Step 3: arena sizing, mothership with the one autopilot behaviour (arc /
   standoff), static target.
2. Step 4: missile launch, missile cam, steering, fuse. **First feel checkpoint** —
   the grin test (success criterion 1).
3. Step 5: boost, early detonate, splash.

From here every change lands on a feature branch via a PR to `main`. See
`CLAUDE.md` §Git flow.

## Open feel questions

None yet — nothing with feel has been built. The first ones will arrive at step 4.

Two things to record when tuning sessions start, because they are free to observe
now and expensive to guess later:

- **`ship.max_engagement_envelope`** — the largest distance a fight actually
  sprawls across. First link in the exploration numbers chain (envelope → disc
  height → cruise speeds → system diameter).
- Whether the hard-cut camera transition or Descent-style PiP wins the round trip
  between missile view and ship view.

## Notes for the next session

- `make check` before calling anything done. `make shot` to look at it yourself.
- Godot 4.7 segfaults if you `ResourceLoader.load()` a `class_name` script with
  `CACHE_MODE_IGNORE`; the test runner uses the default cache mode for that reason.
- `godot --check-only --script foo.gd` cannot see autoloads, so it reports
  "Identifier not found: Tuning" for most files. It is not a usable gate; the
  in-scene-tree test runner is.
