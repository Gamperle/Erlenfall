class_name PromptLine
extends HFlowContainer
## A line of prompt text that can hold drawn input glyphs (InputGlyph) between its words. It stands
## in for a Label: `text` reads as the plain text of the line (and setting it shows plain text),
## and `label_settings` and `horizontal_alignment` style it. Lines wrap between pieces.
##
## A line is a list of segments: a String, or a glyph spec Dictionary (see InputGlyph.spec_for).
## With the `input_glyphs` feature flag off, or when a spec can't be drawn, a spec shows as its text.

## Spaces in a row that end a group of pieces.
const SEPARATOR_SPACES := 3

@export var label_settings: LabelSettings
@export var horizontal_alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT:
	set(value):
		horizontal_alignment = value
		_apply_alignment()

## The line as plain text, exactly what a Label would have shown.
var text: String:
	get:
		return plain_text(_segments)
	set(value):
		set_segments([value])

var _segments: Array = []


static func glyphs_enabled() -> bool:
	return FeatureFlags.enabled("input_glyphs")


## The text of segments joined together.
static func plain_text(segments: Array) -> String:
	var result := ""
	for segment: Variant in segments:
		result += segment if segment is String else str(segment.get("text", ""))
	return result


## Puts `args` into the template's "%s" places. An arg is a String or an Array of segments.
static func segments_for_template(template: String, args: Array) -> Array:
	var parts := template.split("%s")
	var segments: Array = []
	for i in parts.size():
		if parts[i] != "":
			segments.append(parts[i])
		if i < args.size() and i < parts.size() - 1:
			if args[i] is Array:
				segments.append_array(args[i])
			else:
				segments.append(str(args[i]))
	return segments


func _init() -> void:
	add_theme_constant_override("h_separation", 0)
	add_theme_constant_override("v_separation", 2)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_apply_alignment()


func set_template(template: String, args: Array) -> void:
	set_segments(segments_for_template(template, args))


## Callers may set the same line every frame, so an unchanged line costs nothing.
func set_segments(segments: Array) -> void:
	if segments == _segments and get_child_count() > 0:
		return
	_segments = segments
	rebuild()


## Draws the line again, after the text size, flags or accessibility settings changed.
func rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var font_size := _font_size()
	var chunk: HBoxContainer
	# After a glyph, its first word stays with it. After a word that has no space behind it, the next
	# piece stays with it too.
	var glue := false
	for segment: Variant in _segments:
		if segment is Dictionary and glyphs_enabled() and InputGlyph.can_draw(segment) and get_theme_default_font() != null:
			if chunk == null or not glue:
				chunk = _new_chunk()
			chunk.add_child(InputGlyph.new(segment, font_size))
			glue = true
			continue
		var piece: String = segment if segment is String else str(segment.get("text", ""))
		for token in _tokens(piece):
			var blank: bool = token.strip_edges() == ""
			if chunk == null or not (glue or (blank and token.length() < SEPARATOR_SPACES)):
				chunk = _new_chunk()
			chunk.add_child(_label(token))
			if blank:
				# A run of spaces between hints ends the group.
				if token.length() >= SEPARATOR_SPACES:
					chunk = null
					glue = false
				# Spaces right after a glyph keep the glue for the word that follows.
			else:
				# Punctuation such as the colon after a key is not yet the word.
				glue = not token.ends_with(" ") or token.to_upper() == token.to_lower()


## Splits text into words that each carry the spaces after them, so the line can wrap between words.
## Spaces at the start are a piece of their own.
static func _tokens(piece: String) -> PackedStringArray:
	var tokens := PackedStringArray()
	var current := ""
	var in_spaces := false
	for i in piece.length():
		var is_space := piece[i] == " "
		if current != "" and in_spaces and not is_space:
			tokens.append(current)
			current = ""
		in_spaces = is_space
		current += piece[i]
	if current != "":
		tokens.append(current)
	return tokens


## A group of pieces that stay on one row, so a key never wraps away from its text.
func _new_chunk() -> HBoxContainer:
	var chunk := HBoxContainer.new()
	chunk.add_theme_constant_override("separation", 0)
	chunk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(chunk)
	return chunk


func _label(piece: String) -> Label:
	var label := Label.new()
	label.text = piece
	label.label_settings = label_settings
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _font_size() -> int:
	return label_settings.font_size if label_settings != null else get_theme_default_font_size()


func _apply_alignment() -> void:
	match horizontal_alignment:
		HORIZONTAL_ALIGNMENT_CENTER:
			alignment = FlowContainer.ALIGNMENT_CENTER
		HORIZONTAL_ALIGNMENT_RIGHT:
			alignment = FlowContainer.ALIGNMENT_END
		_:
			alignment = FlowContainer.ALIGNMENT_BEGIN
