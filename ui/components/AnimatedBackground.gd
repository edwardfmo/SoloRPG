## Animated background with random image selection, slow pan/zoom, and crossfade.
class_name AnimatedBackground
extends Control

@export var backgrounds: Array[Texture2D] = []
@export var zoom: float = 0.7  ## Portion of image visible (0.5 = 50%, more zoomed)
@export var pan_duration: float = 20.0  ## Seconds to pan across
@export var fade_duration: float = 2.0  ## Crossfade time between images

var _front: TextureRect
var _back: TextureRect
var _shader: Shader
var _tween: Tween
var _last_index: int = -1
var _last_dir_idx: int = 0


func _ready():
	_shader = preload("res://ui/components/pan_zoom.gdshader")

	_back = _create_layer()
	_front = _create_layer()
	add_child(_back)
	add_child(_front)

	if backgrounds.size() > 0:
		_start_cycle()


func _create_layer() -> TextureRect:
	var layer = TextureRect.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	layer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var mat = ShaderMaterial.new()
	mat.shader = _shader
	mat.set_shader_parameter("zoom", zoom)
	mat.set_shader_parameter("pan_offset", Vector2.ZERO)
	layer.material = mat
	return layer


func _start_cycle():
	var tex = _pick_random_texture()
	_front.texture = tex
	_front.modulate.a = 1.0
	_animate_pan(_front, _on_front_pan_done)


func _animate_pan(layer: TextureRect, done_callback: Callable):
	var mat: ShaderMaterial = layer.material
	mat.set_shader_parameter("zoom", zoom)

	# Pick random direction (never same as last)
	var directions = ["left_to_right", "right_to_left", "top_to_bottom", "bottom_to_top"]
	_last_dir_idx = (_last_dir_idx + 1 + (randi() % (directions.size() - 1))) % directions.size()
	var dir = directions[_last_dir_idx]

	var start := Vector2.ZERO
	var end := Vector2.ZERO
	var max_pan = 1.0 - zoom

	match dir:
		"left_to_right":
			start = Vector2(0.0, randf() * max_pan)
			end = Vector2(max_pan, start.y)
		"right_to_left":
			start = Vector2(max_pan, randf() * max_pan)
			end = Vector2(0.0, start.y)
		"top_to_bottom":
			start = Vector2(randf() * max_pan, 0.0)
			end = Vector2(start.x, max_pan)
		"bottom_to_top":
			start = Vector2(randf() * max_pan, max_pan)
			end = Vector2(start.x, 0.0)

	mat.set_shader_parameter("pan_offset", start)

	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(func(v: Vector2):
		mat.set_shader_parameter("pan_offset", v),
		start, end, pan_duration)
	_tween.tween_callback(done_callback)


func _on_front_pan_done():
	_crossfade_to_next()


func _crossfade_to_next():
	# Set up back layer with next image
	var tex = _pick_random_texture()
	_back.texture = tex
	_back.modulate.a = 0.0

	# Move back layer to top for the fade-in
	move_child(_back, get_child_count() - 1)

	# Start panning the back layer
	_animate_pan(_back, _on_front_pan_done)

	# Crossfade: back fades in, front fades out
	var fade_tween = create_tween()
	fade_tween.set_parallel(true)
	fade_tween.tween_property(_back, "modulate:a", 1.0, fade_duration)
	fade_tween.tween_property(_front, "modulate:a", 0.0, fade_duration)
	fade_tween.chain().tween_callback(_on_crossfade_done)


func _on_crossfade_done():
	# Swap references: back is now the visible front
	var temp = _front
	_front = _back
	_back = temp


func _pick_random_texture() -> Texture2D:
	if backgrounds.size() == 0:
		return null
	if backgrounds.size() == 1:
		return backgrounds[0]
	var idx = randi() % backgrounds.size()
	while idx == _last_index:
		idx = randi() % backgrounds.size()
	_last_index = idx
	return backgrounds[idx]
