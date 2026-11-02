class_name InterfaceScale
extends RefCounted
## Keeps the interface from shrinking with the window until its text is too small to read.


## Returns the window's content scale factor. Above 1, the interface is laid out for a smaller screen.
static func factor_for(window_size: Vector2, base_size: Vector2, smallest_scale: float) -> float:
	var stretched := minf(window_size.x / base_size.x, window_size.y / base_size.y)
	if stretched <= 0.0:
		return 1.0
	return maxf(1.0, smallest_scale / stretched)
