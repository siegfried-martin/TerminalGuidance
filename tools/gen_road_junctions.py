#!/usr/bin/env python3
"""Generate the highway's junction tiles — the one place road geometry is AUTHORED.

Every straight edge of the lattice road is stepped from the unit modules in
`gen_road_modules.py` and is exact, because a straight box on a straight segment
meets its neighbour (ADR 0094 says no placement of one on a curve ever can). A
junction is the exception: a ramp leaves the mainline along a curve, and rather than
fit that curve at runtime and then MEASURE what came out — which is what `crossing`,
`overlap`, `_facing`, `_opposite` and span piercing all did, and each of them was
wrong at least once — the curve is solved here, once, and written down beside the
mesh in a sidecar the game reads (ADR 0095).

**THE SIDECAR IS THE CONTRACT, NOT THE MESH.** `road_junction_<name>.json` declares
the footprint, the ramp socket, one lane run per carriageway, the buildings and their
apertures, and the section it was all generated against. `RoadStructure` fills its
`_pierced_*` from that instead of working it out, and the shell barrier still comes
from the path and the section, never from the mesh — so a tile can be dressed as far
as anyone likes and can never change where the player may fly. The `.obj` here is a
placeholder that satisfies the sidecar; real art replaces it in place (ADR 0030).

**THE LOCAL FRAME.** Origin at the start of the edge the tile occupies, `+X` along
the edge (that is `e1`, due east), `+Y` up, `+Z` to the right. Traffic runs on the
right (ADR 0077), so the forward carriageway is at `+Z` and the reverse at `-Z`. A
socket is authored as a cell offset in THIS frame and rotated with the edge when the
tile is placed, which is exact: axial (q, r) turned 60 degrees is (-r, q + r).

**THE FOOTPRINT GROWS UNTIL IT PASSES.** A tile's starting footprint is a proposal.
If the ramp it has to contain would pitch or turn harder than the bounds allow, the
edge gets longer — the tile is the unit that absorbs that, and a junction that is
3.6 km of map is an honest answer where a 6-degree climb crammed into 1.8 km is not.

Run: python3 tools/gen_road_junctions.py   (or `make assets`)
"""

import json
import math
from pathlib import Path

from objlib import Part, write_obj

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "models"
TUNING = ROOT / "tuning.cfg"

# --- Infrastructure constants ------------------------------------------------
# Geometry of the tile itself, not feel. Every one of them is bounded by a check
# the gate repeats against `tuning.cfg`, so none of them can quietly go wrong.

## How far along its run a ramp's samples are taken. Fine enough that
## `max_turn_deg_per_metre` reads the curve rather than the tessellation.
SAMPLE_METRES = 60.0
## The vertical curve at each end of a climb. A merge's rise is a CONSTANT SLOPE with
## these fillets on it, not an S: an S of the same rise over the same run peaks at
## twice the average pitch, which for 240 m over 2.7 km is 11 degrees against a limit
## of 7 — and buying that back by lengthening the tile costs nearly two more
## kilometres of junction. A rounded ramp is both shorter and gentler.
VERTICAL_RADIUS_METRES = 3000.0
## What a ramp's lateral S-curve aims for. Raised to the fillet floor if the floor is
## higher, so a ramp can never turn tighter than the road is allowed to.
RAMP_RADIUS_METRES = 900.0
## How much of the tile is left as plain road after a merge rejoins, so the merge
## finishes inside the tile rather than at its seam.
TAIL_CELLS = 1.0
## The placeholder's own proportions, matching `gen_road_modules.py` so the two read
## as the same road: how far a collar stands proud, how thick a pane is, how deep the
## roadway slab hangs, and how many collars a tile carries per cell.
PROUD = 0.07
PANE_METRES = 3.0
DECK_FRACTION = 0.06
ROOT3_OVER_2 = 0.8660254037844386

## The catalogue. Footprints and socket cells are STARTING VALUES (plan section 6.2).
CATALOGUE = [
    {
        "name": "diverge_right",
        # An exit. It leaves at lane height and its building is CUT rather than
        # troughed (ADR 0092): its roadway and the highway's are the same surface,
        # so walls standing in the lane are the thing you fly into.
        "kind": "exit",
        "footprint_cells": 3,
        "socket": (3, -1),
        "socket_level": 0,
    },
    {
        "name": "merge_below",
        # An entry. It arrives two levels down — far enough under the mainline's
        # floor for a lane route to pass beneath it — and climbs through the roadway,
        # a trough rising into a slot (ADR 0091).
        "kind": "entry",
        "footprint_cells": 5,
        "socket": (1, -1),
        "socket_level": -2,
    },
]


# --- tuning.cfg --------------------------------------------------------------

def read_tuning(section):
    """The values of one `[section]` of tuning.cfg. A ConfigFile is `key = value`
    with `;` comments (ADR 0033); nothing here needs more than that."""
    values = {}
    current = None
    for line in TUNING.read_text().split("\n"):
        stripped = line.strip()
        if stripped.startswith("[") and stripped.endswith("]"):
            current = stripped[1:-1]
            continue
        if current != section or "=" not in stripped or stripped.startswith(";"):
            continue
        key, _, raw = stripped.partition("=")
        raw = raw.split(";")[0].strip()
        try:
            values[key.strip()] = float(raw)
        except ValueError:
            pass
    return values


# --- The lattice -------------------------------------------------------------

def cell_to_local(cell, level, cell_metres, level_metres):
    q, r = cell
    return (cell_metres * (q + r * 0.5),
            level_metres * level,
            -cell_metres * r * ROOT3_OVER_2)


# --- Solving a ramp ----------------------------------------------------------

def lateral_run_for(offset, radius_target):
    """How much run a lateral S of `offset` needs to come out at `radius_target`."""
    run = abs(offset)
    for _ in range(200):
        phi = 2.0 * math.atan2(abs(offset), run)
        radius = run / (2.0 * math.sin(phi))
        if abs(radius - radius_target) < 0.01:
            break
        run *= (radius_target / radius) ** 0.5
    return run


def lateral_at(u, run, offset):
    """A point on the lateral S at fraction `u` of the run, as (along, across)."""
    phi = 2.0 * math.atan2(abs(offset), run)
    if phi <= 1e-9:
        return u * run, 0.0
    radius = run / (2.0 * math.sin(phi))
    sign = 1.0 if offset >= 0.0 else -1.0
    half = 0.5 * run
    along = u * run
    if along <= half:
        t = math.asin(min(1.0, along / radius))
        return radius * math.sin(t), sign * radius * (1.0 - math.cos(t))
    back = run - along
    t = math.asin(min(1.0, back / radius))
    return run - radius * math.sin(t), offset - sign * radius * (1.0 - math.cos(t))


def climb_slope(run, rise, radius):
    """The constant slope of a rounded climb: `rise` over `run`, with a vertical
    fillet of `radius` at each end. Solved rather than assumed, because the fillets
    eat into the run and a slope that ignores them arrives short."""
    if abs(rise) < 1e-6:
        return 0.0
    low, high = 0.0, math.radians(80.0)
    for _ in range(80):
        mid = 0.5 * (low + high)
        straight = run - 2.0 * radius * math.sin(mid)
        reached = 2.0 * radius * (1.0 - math.cos(mid)) + max(straight, 0.0) * math.tan(mid)
        if reached < abs(rise):
            low = mid
        else:
            high = mid
    return 0.5 * (low + high)


def climb_at(u, run, rise, radius):
    """The height of a rounded climb at fraction `u` of the run."""
    if abs(rise) < 1e-6:
        return 0.0
    sigma = climb_slope(run, rise, radius)
    sign = 1.0 if rise >= 0.0 else -1.0
    tangent = radius * math.sin(sigma)
    lift = radius * (1.0 - math.cos(sigma))
    along = u * run
    if along <= tangent:
        return sign * (radius - math.sqrt(max(radius * radius - along * along, 0.0)))
    if along >= run - tangent:
        back = run - along
        return sign * (abs(rise) - (radius - math.sqrt(max(radius * radius - back * back, 0.0))))
    return sign * (lift + (along - tangent) * math.tan(sigma))


def ramp_run(start, end, radius, samples):
    """A ramp's polyline: a lateral S and a rounded climb over the same run, both
    leaving and arriving parallel to the edge."""
    run = end[0] - start[0]
    offset = end[2] - start[2]
    rise = end[1] - start[1]
    points = []
    for i in range(samples + 1):
        u = i / samples
        along, across = lateral_at(u, run, offset)
        points.append((start[0] + along,
                       start[1] + climb_at(u, run, rise, radius),
                       start[2] + across))
    return points


# --- Reading a polyline ------------------------------------------------------

def polyline_length(points):
    return sum(math.dist(points[i - 1], points[i]) for i in range(1, len(points)))


def along_at(points, index):
    return polyline_length(points[:index + 1])


def steepest_pitch(points):
    worst = 0.0
    for i in range(1, len(points)):
        a, b = points[i - 1], points[i]
        flat = math.hypot(b[0] - a[0], b[2] - a[2])
        if flat > 1e-6:
            worst = max(worst, math.degrees(math.atan2(abs(b[1] - a[1]), flat)))
    return worst


def max_turn_deg_per_metre(points):
    worst = 0.0
    for i in range(1, len(points) - 1):
        back = [points[i][k] - points[i - 1][k] for k in range(3)]
        ahead = [points[i + 1][k] - points[i][k] for k in range(3)]
        bl = math.sqrt(sum(c * c for c in back))
        al = math.sqrt(sum(c * c for c in ahead))
        if bl < 1e-6 or al < 1e-6:
            continue
        cosine = sum(back[k] * ahead[k] for k in range(3)) / (bl * al)
        turn = math.degrees(math.acos(max(-1.0, min(1.0, cosine))))
        worst = max(worst, turn / (0.5 * (bl + al)))
    return worst


def first_crossing(points, across, rising):
    """Where a run's `z` first passes `across`: (distance along it, the point).

    This is the whole of what a junction used to MEASURE at runtime — where the ramp
    is in the mainline's way — done once, here, against a curve that is not going to
    move. `None` when it never crosses, which the caller treats as "the whole run".
    """
    for i in range(1, len(points)):
        a, b = points[i - 1][2], points[i][2]
        if (rising and b >= across > a) or (not rising and b <= across < a):
            share = 0.0 if abs(b - a) < 1e-9 else (across - a) / (b - a)
            span = math.dist(points[i - 1], points[i])
            point = tuple(points[i - 1][k] + share * (points[i][k] - points[i - 1][k])
                          for k in range(3))
            return along_at(points, i - 1) + span * share, point
    return None


def slice_run(points, from_along):
    """The tail of a run from `from_along` onward, with a real vertex at the cut so
    the building starts exactly where the sidecar says it does."""
    if from_along <= 1e-6:
        return list(points)
    out = []
    for i in range(1, len(points)):
        low = along_at(points, i - 1)
        high = along_at(points, i)
        if high < from_along:
            continue
        if not out:
            share = 0.0 if high - low < 1e-9 else (from_along - low) / (high - low)
            out.append(tuple(points[i - 1][k] + share * (points[i][k] - points[i - 1][k])
                             for k in range(3)))
        out.append(points[i])
    return out


# --- The placeholder mesh ----------------------------------------------------

def frames(points):
    """A right-handed frame per point: forward along the run, right, and up."""
    out = []
    for i in range(len(points)):
        a = points[max(i - 1, 0)]
        b = points[min(i + 1, len(points) - 1)]
        forward = [b[k] - a[k] for k in range(3)]
        span = math.sqrt(sum(c * c for c in forward)) or 1.0
        forward = [c / span for c in forward]
        right = [forward[1] * 0.0 - forward[2] * 1.0,
                 0.0,
                 forward[0] * 1.0 - forward[1] * 0.0]
        span = math.hypot(right[0], right[2]) or 1.0
        right = [right[0] / span, 0.0, right[2] / span]
        up = [right[1] * forward[2] - right[2] * forward[1],
              right[2] * forward[0] - right[0] * forward[2],
              right[0] * forward[1] - right[1] * forward[0]]
        out.append((forward, right, up))
    return out


def quad(point, frame, across, below, above):
    """The four corners of a cross-section slab, in the run's own frame."""
    _, right, up = frame
    corners = []
    for a, b in ((across[0], below), (across[1], below),
                 (across[1], above), (across[0], above)):
        corners.append(tuple(point[k] + right[k] * a + up[k] * b for k in range(3)))
    return corners


def sweep(points, across, below, above, skip):
    """Box segments along a run, leaving out any segment inside a `skip` stretch."""
    parts = []
    marks = frames(points)
    for i in range(1, len(points)):
        middle = 0.5 * (along_at(points, i - 1) + along_at(points, i))
        if any(low <= middle <= high for low, high in skip):
            continue
        a = quad(points[i - 1], marks[i - 1], across, below, above)
        b = quad(points[i], marks[i], across, below, above)
        parts.append(Part(list(a) + list(b),
                          [[0, 1, 2, 3], [4, 5, 6, 7], [0, 1, 5, 4],
                           [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7]]))
    return parts


def building_mesh(points, half_width, half_height, open_faces):
    """A placeholder building: a roadway slab and a kerb in metal, glazing in glass,
    each face left out over the stretches the sidecar says are open.

    The unit-section contract of `gen_road_modules.py` holds here too: every piece
    sits ON or OUTSIDE the clear interior, so the space a ship flies through is
    exactly the lane and nothing reaches inward to eat it.
    """
    deck = half_height * 2.0 * DECK_FRACTION
    metal = sweep(points, (-half_width, half_width),
                  -half_height - deck, -half_height, open_faces.get("BELOW", []))
    glass = []
    glass += sweep(points, (half_width, half_width + PANE_METRES),
                   -half_height, half_height, open_faces.get("RIGHT", []))
    glass += sweep(points, (-half_width - PANE_METRES, -half_width),
                   -half_height, half_height, open_faces.get("LEFT", []))
    glass += sweep(points, (-half_width, half_width),
                   half_height, half_height + PANE_METRES, open_faces.get("ABOVE", []))
    return metal, glass


def collars(points, half_width, half_height, thickness, spacing):
    """A collar every `spacing` metres: a short length of full section standing
    proud of the glazing. The rhythm of a built thing, and the tile's landmarks."""
    parts = []
    span = polyline_length(points)
    proud_w = half_width * (1.0 + PROUD)
    proud_h = half_height * (1.0 + PROUD)
    at = spacing
    marks = frames(points)
    while at < span - thickness:
        index = 1
        while index < len(points) - 1 and along_at(points, index) < at:
            index += 1
        head = points[index]
        frame = marks[index]
        step = [frame[0][k] * thickness * 0.5 for k in range(3)]
        a = quad([head[k] - step[k] for k in range(3)], frame,
                 (-proud_w, proud_w), -proud_h, proud_h)
        b = quad([head[k] + step[k] for k in range(3)], frame,
                 (-proud_w, proud_w), -proud_h, proud_h)
        parts.append(Part(list(a) + list(b),
                          [[0, 1, 2, 3], [4, 5, 6, 7], [0, 1, 5, 4],
                           [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7]]))
        at += spacing
    return parts


# --- Building one tile -------------------------------------------------------

def solve(entry, tune):
    """One tile, grown until every bound passes. Returns the sidecar dictionary,
    the metal parts and the glass parts."""
    cell = tune["lattice_cell_metres"]
    level = tune["lattice_level_metres"]
    lane_w = tune["lane_width"]
    lane_h = tune["lane_height"]
    deck_sep = tune["deck_separation"]
    rib = tune["structure_rib_thickness"]
    pitch_max = tune["road_pitch_max_deg"]
    turn_max = tune["cruise_turn_rate_deg_per_sec"]
    speed = tune["cruise_speed"]

    floor = max(speed / math.radians(turn_max), deck_sep)
    radius_target = max(RAMP_RADIUS_METRES, floor)
    main_half = deck_sep * 0.5 + lane_w * 0.5
    ramp_half = lane_w * 0.5
    # Where the ramp's body has fully left the mainline's, so the two buildings stop
    # sharing a wall. Not measured at runtime — decided here, once.
    clear_across = main_half + ramp_half

    cells = entry["footprint_cells"]
    for _attempt in range(24):
        length = cells * cell
        socket = cell_to_local(entry["socket"], entry["socket_level"], cell, level)
        forward_z = deck_sep * 0.5
        if entry["kind"] == "exit":
            # An exit leaves the carriageway and reaches the socket. The divergence
            # is DERIVED from the radius we are willing to turn at, rather than
            # picked: a ramp that peels away at the tile's seam is flush with the
            # wall for its whole length, and that is the highway losing a side
            # (ADR 0093).
            run = min(lateral_run_for(socket[2] - forward_z, radius_target), socket[0])
            start = (socket[0] - run, 0.0, forward_z)
            end = socket
        else:
            # An entry arrives at the socket and climbs to the carriageway, finishing
            # inside the tile with a tail of plain road after it.
            start = socket
            end = (length - TAIL_CELLS * cell, 0.0, forward_z)
            run = end[0] - start[0]
        if run <= cell * 0.5:
            cells += 1
            continue

        samples = max(int(math.ceil(run / SAMPLE_METRES)), 8)
        ramp = ramp_run(start, end, VERTICAL_RADIUS_METRES, samples)
        pitch = steepest_pitch(ramp)
        demanded = max_turn_deg_per_metre(ramp) * speed
        # A margin, so a tile is not one tuning nudge away from failing the gate it
        # was generated to pass.
        if pitch > pitch_max * 0.9 or demanded > turn_max * 0.9:
            cells += 1
            continue

        spine = [(0.0, 0.0, 0.0), (length, 0.0, 0.0)]
        carriage_f = [(0.0, 0.0, forward_z), (length, 0.0, forward_z)]
        carriage_r = [(length, 0.0, -forward_z), (0.0, 0.0, -forward_z)]
        return _assemble(entry, ramp, spine, carriage_f, carriage_r, socket, length,
                         cells, main_half, ramp_half, lane_h, rib, clear_across,
                         cell, level, lane_w, deck_sep, pitch, demanded)
    raise SystemExit("%s: no footprint up to %d cells satisfies the bounds"
                     % (entry["name"], cells))


def _assemble(entry, ramp, spine, carriage_f, carriage_r, socket, length, cells,
              main_half, ramp_half, lane_h, rib, clear_across, cell, level,
              lane_w, deck_sep, pitch, demanded):
    half_h = lane_h * 0.5
    ramp_length = polyline_length(ramp)
    apertures = []
    ramp_from = 0.0

    if entry["kind"] == "exit":
        # The mainline's RIGHT wall is open exactly while the ramp's body straddles
        # it, and the ramp's own building starts where it is CUT clear of the highway
        # (ADR 0092): an exit leaves at lane height, so its walls would otherwise
        # stand in the lane you are trying to reach it from.
        crossed = first_crossing(ramp, clear_across, True)
        clears, clear_at = crossed if crossed else (ramp_length, ramp[-1])
        apertures.append({"building": "mainline", "run": "spine",
                          "from": ramp[0][0], "to": clear_at[0],
                          "face": "RIGHT"})
        ramp_from = clears
        gate = {"at": list(ramp[0]), "facing": [1.0, 0.0, 0.0]}
    else:
        # A merge is a trough rising into a slot (ADR 0091): the highway's ROADWAY is
        # open for the whole of it, and over the same stretch the ramp loses its ROOF
        # and keeps its floor and walls.
        crossed = first_crossing(ramp, clear_across, False)
        enters, enter_at = crossed if crossed else (0.0, ramp[0])
        apertures.append({"building": "mainline", "run": "spine",
                          "from": enter_at[0], "to": length, "face": "BELOW"})
        apertures.append({"building": "ramp", "run": "ramp",
                          "from": enters, "to": ramp_length, "face": "ABOVE"})
        gate = None

    buildings = [
        {"name": "mainline", "run": "spine", "from": 0.0, "to": length,
         "profile": "pair"},
        {"name": "ramp", "run": "ramp", "from": ramp_from, "to": ramp_length,
         "profile": "lane"},
    ]

    open_main = {}
    open_ramp = {}
    for aperture in apertures:
        target = open_main if aperture["building"] == "mainline" else open_ramp
        low = aperture["from"] - (0.0 if aperture["building"] == "mainline" else ramp_from)
        target.setdefault(aperture["face"], []).append(
            (low, aperture["to"] - (0.0 if aperture["building"] == "mainline" else ramp_from)))

    metal, glass = building_mesh(spine, main_half, half_h, open_main)
    metal += collars(spine, main_half, half_h, rib, cell)
    ramp_building = slice_run(ramp, ramp_from)
    if len(ramp_building) >= 2:
        ramp_metal, ramp_glass = building_mesh(ramp_building, ramp_half, half_h, open_ramp)
        metal += ramp_metal
        glass += ramp_glass
        metal += collars(ramp_building, ramp_half, half_h, rib, cell)

    sidecar = {
        "tile": entry["name"],
        "generated_by": "tools/gen_road_junctions.py",
        "footprint": [cells, 0],
        "profile": "pair",
        "ramp_profile": "lane",
        "sockets": {"ramp": {"cell": list(entry["socket"]),
                             "level": entry["socket_level"],
                             "heading": [1, 0]}},
        "lane_runs": {
            "spine": [list(p) for p in spine],
            "forward": [list(p) for p in carriage_f],
            "reverse": [list(p) for p in carriage_r],
            "ramp": [list(p) for p in ramp],
        },
        "buildings": buildings,
        "apertures": apertures,
        "section": {
            "lane_width": lane_w,
            "lane_height": lane_h,
            "deck_separation": deck_sep,
            "structure_rib_thickness": rib,
            "lattice_cell_metres": cell,
            "lattice_level_metres": level,
        },
    }
    if gate is not None:
        sidecar["gate"] = gate
    print("  %-14s footprint (%d,0) = %.0f m, ramp %.0f m, pitch %.2f deg, "
          "demands %.1f deg/s, socket at (%d,%d) level %d"
          % (entry["name"], cells, length, ramp_length, pitch, demanded,
             entry["socket"][0], entry["socket"][1], entry["socket_level"]))
    del socket
    return sidecar, metal, glass


def main():
    tune = read_tuning("exploration")
    print("junction tiles, against lane %.0f x %.0f, decks %.0f apart, cell %.0f m:"
          % (tune["lane_width"], tune["lane_height"], tune["deck_separation"],
             tune["lattice_cell_metres"]))
    for entry in CATALOGUE:
        sidecar, metal, glass = solve(entry, tune)
        stem = "road_junction_%s" % entry["name"]
        write_obj(OUT / ("%s_metal.obj" % stem), "%s_metal" % stem, metal,
                  "gen_road_junctions.py", uv_scale=1.0 / 400.0)
        write_obj(OUT / ("%s_glass.obj" % stem), "%s_glass" % stem, glass,
                  "gen_road_junctions.py", uv_scale=1.0 / 400.0)
        (OUT / ("%s.json" % stem)).write_text(json.dumps(sidecar, indent=2) + "\n")
        print("wrote %s" % (OUT / ("%s.json" % stem)))


if __name__ == "__main__":
    main()
