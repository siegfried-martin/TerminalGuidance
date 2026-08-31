class_name BoundaryConstraint
extends RefCounted
## One boundary surface, as felt at one point: how far past it you are, and which
## way is out. Pure data — no scene tree, no tuning, no disk.
##
## This is the whole vocabulary the boundary speaks. The red, the strain and the
## damage timer all read these two numbers and none of them knows what shape
## produced them, which is what lets a disc, a corridor and a whole-map boundary be
## *different constraint sets rather than different code* (ADR 0062).

## Metres past this surface. Negative inside, zero on it, positive outside.
var depth: float = 0.0
## Unit vector pointing out of the good zone, here.
var outward: Vector3 = Vector3.ZERO


func _init(past: float, out_dir: Vector3) -> void:
	depth = past
	outward = out_dir
