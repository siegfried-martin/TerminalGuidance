class_name FarLayer
extends RefCounted
## The compressed far layer (`docs/PROJECT_OVERVIEW.md`, distant-object LOD): things
## beyond `start` metres are drawn SMALLER than perspective would make them, shrinking
## with distance faster than one over distance, so a system's neighbours read as far
## away rather than as large. Pure — one function, shared by the nodes that scale
## themselves (planets, stars) and, as the same formula in GLSL, by the road's far
## mesh and markings.
##
## Apparent size falls as `1 / d^(1 + power)`: at power 0 it is honest perspective,
## at 1 things twice as far look four times smaller. Within `start` nothing changes,
## which is what keeps the near world — and the road's detailed chunks — exact.


static func factor(distance: float, start: float, power: float) -> float:
	if distance <= start or start <= 0.0:
		return 1.0
	return pow(start / distance, maxf(power, 0.0))
