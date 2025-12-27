extends Camera2D

# Camera that follows the player with zoom controls

@export var target_path: NodePath
var target: Node2D

# Zoom settings
var zoom_level := 1.0
const MIN_ZOOM := 0.001  # Zoomed out to see whole solar system
const MAX_ZOOM := 10.0   # Zoomed in close
const ZOOM_SPEED := 0.1

func _ready():
	if target_path:
		target = get_node_or_null(target_path)

	# Start zoomed out enough to see inner planets
	zoom_level = 0.5
	zoom = Vector2(zoom_level, zoom_level)

func _process(_delta):
	if target:
		position = target.position

	handle_zoom_input()

func handle_zoom_input():
	var zoom_changed := false

	# Mouse wheel zoom
	if Input.is_action_just_pressed("zoom_in"):
		zoom_level *= 1.2
		zoom_changed = true
	if Input.is_action_just_pressed("zoom_out"):
		zoom_level /= 1.2
		zoom_changed = true

	# Keyboard zoom (+ and -)
	if Input.is_action_pressed("ui_focus_next"):  # Usually Tab, we'll add custom
		zoom_level *= 1.02
		zoom_changed = true
	if Input.is_action_pressed("ui_focus_prev"):
		zoom_level /= 1.02
		zoom_changed = true

	if zoom_changed:
		zoom_level = clamp(zoom_level, MIN_ZOOM, MAX_ZOOM)
		zoom = Vector2(zoom_level, zoom_level)
