class_name NBDiscMotion
extends RefCounted

# Pure time-to-phase function: physics outcome is independent of visual FPS.
# For REWIND the phase moves forward one bar, backward the next, using
# a 160ms analytically integrated deceleration/re-acceleration envelope.
# Warnings occur two beats before each deterministic reversal boundary.
var initial_phase := 0.0
var base_velocity := 0.0
var period := 2.0
var variant := "NORMAL"

func configure(start_angle: float, bpm: float, speed_multiplier: float, special: String) -> void:
	initial_phase = start_angle
	period = 240.0 / bpm
	base_velocity = TAU / period * speed_multiplier
	variant = special

func phase_at(t: float) -> float:
	var s := maxf(0.0, t)
	if variant == "PULSE":
		var full := int(floor(s / period))
		var partial := s - float(full) * period
		var low_bars := int((full + 1) / 2)
		var high_bars := int(full / 2)
		return initial_phase + base_velocity * (period * (low_bars * 0.85 + high_bars * 1.15) + partial * (0.85 if full % 2 == 0 else 1.15))
	if variant == "REWIND":
		var full := int(floor(s / period))
		var partial := s - float(full) * period
		var ramp := minf(.16, period * .11)
		var cycle_area := period - ramp
		var partial_area := _rewind_integral(partial, ramp)
		return initial_phase + base_velocity * (
			(cycle_area if full % 2 == 1 else 0.0) + partial_area * (1.0 if full % 2 == 0 else -1.0))
	return initial_phase + base_velocity * s

func upcoming_warning(t: float) -> Dictionary:
	if variant != "REWIND" and variant != "PULSE":
		return {"active": false}
	var remain := period - fposmod(t, period)
	var warning_time := period * 0.5
	return {"active": remain <= warning_time, "progress": 1.0 - remain / warning_time,
		"text": ("REVERSAL" if variant == "REWIND" else "TEMPO SHIFT")}

func _rewind_integral(t: float, ramp: float) -> float:
	if t < ramp:
		return .5 * t - ramp / (2.0 * PI) * sin(PI * t / ramp)
	if t <= period - ramp:
		return .5 * ramp + (t - ramp)
	var tail := t - (period - ramp)
	return period - 1.5 * ramp + .5 * tail + ramp / (2.0 * PI) * sin(PI * tail / ramp)
