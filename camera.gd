extends Camera2D

# Camera that follows the player with zoom controls
# Zoom: Mouse wheel, +/-, or Q/E

var target: Node2D

# Zoom settings
var zoom_level := 0.3
const MIN_ZOOM := 0.0005  # Zoomed out to see whole solar system
const MAX_ZOOM := 20.0    # Zoomed in close
const ZOOM_STEP := 1.3    # Multiplier per zoom action
const ZOOM_SMOOTH := 10.0 # Smoothing speed

var target_zoom := 0.3

func _ready():
	# Get the player (parent node)
	target = get_parent()
	target_zoom = zoom_level
	zoom = Vector2(zoom_level, zoom_level)

func _process(delta):
	# Smooth zoom
	zoom_level = lerp(zoom_level, target_zoom, ZOOM_SMOOTH * delta)
	zoom = Vector2(zoom_level, zoom_level)

func _unhandled_input(event):
	# Mouse wheel zoom
	if event is InputEventMouseButton:
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				zoom_in()
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				zoom_out()

func _input(_event):
	# Keyboard zoom (continuous while held)
	if Input.is_action_pressed("zoom_in"):
		target_zoom = clamp(target_zoom * 1.02, MIN_ZOOM, MAX_ZOOM)
	if Input.is_action_pressed("zoom_out"):
		target_zoom = clamp(target_zoom / 1.02, MIN_ZOOM, MAX_ZOOM)

func zoom_in():
	target_zoom = clamp(target_zoom * ZOOM_STEP, MIN_ZOOM, MAX_ZOOM)

func zoom_out():
	target_zoom = clamp(target_zoom / ZOOM_STEP, MIN_ZOOM, MAX_ZOOM)

func get_zoom_level() -> float:
	return zoom_level
