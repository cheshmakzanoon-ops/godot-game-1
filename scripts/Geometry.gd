class_name NBGeometry
extends RefCounted

const FULL := TAU
const HIT_DEG := 12.0
const EDGE_DEG := 19.0
const PERFECT_DEG := 7.0
const FLIGHT := 0.11
const FIRE_ANGLE := PI * 0.5

static func wrap(angle: float) -> float:
	return fposmod(angle, TAU)

static func angular_distance(a: float, b: float) -> float:
	var delta := absf(wrap(a) - wrap(b))
	return minf(delta, TAU - delta)

static func clearance(local_angle: float, pins: Array, lane: int) -> float:
	var best := TAU
	for pin in pins:
		if int(pin.get("lane", 0)) == lane:
			best = minf(best, angular_distance(local_angle, float(pin["angle"])))
	return best

static func evaluate(local_angle: float, pins: Array, lane: int) -> Dictionary:
	var nearest := rad_to_deg(clearance(local_angle, pins, lane))
	var grid_angle := float(roundi(local_angle / TAU * 16.0)) * TAU / 16.0
	var perfect := rad_to_deg(angular_distance(local_angle, grid_angle)) <= PERFECT_DEG
	return {
		"hit": nearest <= HIT_DEG,
		"edge": nearest > HIT_DEG and nearest <= EDGE_DEG,
		"perfect": perfect,
		"clearance": nearest,
		"step": posmod(roundi(local_angle / TAU * 16.0), 16)
	}

static func impact_local_angle(fire_time: float, motion: NBDiscMotion) -> float:
	return wrap(FIRE_ANGLE - motion.phase_at(fire_time + FLIGHT))
