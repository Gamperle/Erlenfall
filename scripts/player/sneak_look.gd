class_name SneakLook
extends RefCounted
## How sneaking looks (#207): the model crouches and walks with a slower cycle, using the shared
## Crouch_Idle and Crouch_Fwd animations. Off with the `sneak_animation` flag.


static func apply(player: Player, model: CharacterModel) -> void:
	model.crouched = FeatureFlags.enabled("sneak_animation") and player.is_sneaking()
	model.crouch_speed = float(FeatureFlags.value("sneak_animation_speed", 0.8))
