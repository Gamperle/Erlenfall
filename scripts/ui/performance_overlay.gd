class_name PerformanceOverlay
extends Label
## Shows frame rate and rendering measurements, refreshed a few times per second.

const REFRESH_SECONDS := 0.5

var _since_refresh := 0.0
var _slowest_frame := 0.0


func _process(delta: float) -> void:
	_slowest_frame = maxf(_slowest_frame, delta)
	_since_refresh += delta
	if _since_refresh >= REFRESH_SECONDS:
		_since_refresh = 0.0
		refresh()
		_slowest_frame = 0.0


func refresh() -> void:
	var fps := Performance.get_monitor(Performance.TIME_FPS)
	text = tr("UI_METRICS") % [
		fps,
		_slowest_frame * 1000.0,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000.0,
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
	]
