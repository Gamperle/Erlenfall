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


## How long after the button goes down the weapon starts to rise, so a tap doesn't flash the pose.
static func pose_delay_seconds() -> float:
	return float(FeatureFlags.value("heavy_swing_pose_delay_seconds", 0.15))


## How long a heavy swing takes to land after release. A tap's is shorter, so a heavy hit is slower to come.
static func windup_seconds() -> float:
	return float(FeatureFlags.value("heavy_swing_windup_seconds", 0.3))


## How many times the normal recovery after a swing a heavy swing takes.
static func recovery_factor() -> float:
	return float(FeatureFlags.value("heavy_swing_recovery_factor", 1.4))


## How full the charge is for a button held this long, from 0 to 1. Full means the swing will be heavy.
static func charge_fraction(held_seconds: float) -> float:
	return clampf(held_seconds / maxf(charge_seconds(), 0.01), 0.0, 1.0)
