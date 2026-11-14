class_name AudioBuses
extends RefCounted
## The game's audio buses. Sound code picks a bus through here, so the volume settings reach every sound.

const MASTER := "Master"
const MUSIC := "Music"
const EFFECTS := "Effects"
const AMBIENCE := "Ambience"
## The buses that have a volume setting, in the order the settings screen lists them.
const ALL: Array[String] = [MASTER, MUSIC, EFFECTS, AMBIENCE]


## Creates the buses that are missing. Music, Effects, and Ambience feed into Master.
static func ensure() -> void:
	for bus_name: String in ALL:
		if AudioServer.get_bus_index(bus_name) != -1:
			continue
		AudioServer.add_bus()
		var index := AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, MASTER)


## Sets a bus to a volume from 0 (silent) to 1 (full).
static func set_volume(bus_name: String, volume: float) -> void:
	ensure()
	var index := AudioServer.get_bus_index(bus_name)
	AudioServer.set_bus_volume_db(index, linear_to_db(volume))
	AudioServer.set_bus_mute(index, volume <= 0.0)


## Puts a player on a bus, for example `AudioBuses.route(player, AudioBuses.MUSIC)`. Falls back to Master for an unknown name.
static func route(player: Node, bus_name: String) -> void:
	ensure()
	player.bus = bus_name if AudioServer.get_bus_index(bus_name) != -1 else MASTER
