# ADR 0050 — One unguided missile in the air, and the second click is the mechanic

*Status: accepted · 2026-08-27 · from building stage 3 of `docs/TURRET_MODE_IMPLEMENTATION.md`*

## Decision

1. **A weapon is either held or clicked, and which one is a property of the
   weapon.** The autocannon and the pulse beam are held. The unguided missile and
   the blockers are clicked — one press, one round.
2. **Exactly one unguided missile is in the air at a time.** While one is flying,
   the button detonates it instead of launching another.
3. **The edge is detected by the turret itself**, from last frame's trigger state,
   not by `Input.is_action_just_pressed`.
4. **A blast is drawn at exactly the radius it damaged.** The detonation flash's
   end radius *is* the splash radius; there is no second number.
   `missile/flash_end_radius` is gone, replaced by `missile/splash_radius`.

## Why

**1 and 2 are the same decision seen twice.** The human's specification is precise
about this weapon: *"click once to fire and click again to force an explosion."*
That second click is the whole mechanic — it is what turns a miss into a chosen
detonation point, and it is what lets one round reach several components at once,
which is the reason the weapon exists.

Both halves of it die if the trigger is held. On a held trigger a magazine of ten
empties in a fifth of a second, and with a dozen rounds in the air "click again"
has no referent — which one goes off? One at a time makes the second click a
decision with a subject.

It also produces the weapon's real texture: you are always either holding a shot or
holding a detonator, never both, and the cost of firing again is committing the one
you have.

**3 is about being able to test it at all.** `Input.is_action_just_pressed` is keyed
to the engine's frame counter, which does not advance when the headless gate steps
`_process` by hand — a magazine weapon would empty in a single "frame" under test,
and the click-versus-hold distinction would be exactly the thing that could not be
verified. Fifteen lines of edge tracking buys a behavioural test of the mechanic
this ADR exists to protect.

**4 is the same rule the rocks and the hull are built on**, arriving for the third
time. ADR 0041 made a rock's drawn lobes its hit shape; ADR 0043 made the hull's
drawn boxes its hit volumes, after the version with a separate hit sphere shipped a
bug the player experienced as "my aim can't be that bad". A blast that looks bigger
than it reaches is the same failure in a different costume, and it is *worse*,
because the player is judging "did that reach the other component" from a sphere
that expands and fades in half a second and cannot be studied.

## What this forbids

- **Do not put the unguided missile or the blockers on a held trigger**, and do not
  add an auto-repeat. If a future weapon wants both, it declares which it is in
  `Turret.is_click_weapon` rather than reading the input twice.
- **Do not allow more than one unguided missile in flight**, and do not "improve"
  the second click into detonate-all or detonate-nearest. The referent has to stay
  unambiguous.
- **Do not go back to `Input.is_action_just_pressed`** for weapon triggers. It
  cannot be stepped by hand and would silently remove the gate's ability to tell a
  click from a hold.
- **Do not give a blast a separate visual radius.** If a flash needs to read bigger,
  the blast gets bigger — or the colour changes, or it lasts longer. The radius is
  one number.
