class_name HeavySwing
extends RefCounted
## The heavy swing: holding the attack button charges a harder hit that costs stamina. Tuned in `data/feature_flags.json`.


## Whether holding the attack button charges a heavy swing. Needs the `heavy_swing` flag.
static func enabled() -> bool:
	return FeatureFlags.enabled("heavy_swing")


## How long the button must be held, in seconds, before the swing counts as heavy.
static func charge_seconds() -> float:
	return float(FeatureFlags.value("heavy_swing_charge_seconds", 0.6))


## How many times the normal damage a heavy swing does.
static func damage_factor() -> float:
	return float(FeatureFlags.value("heavy_swing_damage_factor", 2.0))


## The stamina a heavy swing costs. Free when the `stamina` flag is off.
static func stamina_cost() -> float:
	return float(FeatureFlags.value("heavy_swing_stamina_cost", 30.0))


## Whether a button held this many seconds gives a heavy swing.
static func is_charged(held_seconds: float) -> bool:
	return enabled() and held_seconds >= charge_seconds()
