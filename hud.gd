extends CanvasLayer

@onready var speed_label: Label = $MarginContainer/VBoxContainer/SpeedLabel
@onready var accel_label: Label = $MarginContainer/VBoxContainer/AccelLabel
@onready var time_label: Label = $MarginContainer/VBoxContainer/TimeLabel
@onready var position_label: Label = $MarginContainer/VBoxContainer/PositionLabel
@onready var nearest_label: Label = $MarginContainer/VBoxContainer/NearestLabel
@onready var controls_label: Label = $MarginContainer/VBoxContainer/ControlsLabel

var player: Node2D
var solar_system: Node2D

const KM_PER_UNIT := 1_000_000.0

func _ready():
	# Find references after a short delay to ensure scene is ready
	await get_tree().process_frame
	player = get_node_or_null("../Player")
	solar_system = get_node_or_null("..")

func _process(_delta):
	if not player or not solar_system:
		return

	update_speed_display()
	update_accel_display()
	update_time_display()
	update_position_display()
	update_nearest_display()

func update_speed_display():
	var speed = player.get_speed_km_s()
	speed_label.text = "Speed: " + format_speed(speed)

func update_accel_display():
	var accel = player.get_acceleration_g()
	if accel > 0:
		accel_label.text = "Thrust: %.1fg" % accel
	else:
		accel_label.text = "Thrust: Coasting"

func update_time_display():
	var time_scale = solar_system.get_time_scale()
	time_label.text = "Time: " + format_time_scale(time_scale)

func update_position_display():
	var pos = player.position
	var distance_from_sun = pos.length()
	position_label.text = "From Sun: " + format_distance(distance_from_sun)

func update_nearest_display():
	var nearest = find_nearest_planet()
	if nearest:
		nearest_label.text = "Nearest: " + nearest

func find_nearest_planet() -> String:
	if not solar_system or not solar_system.planets:
		return ""

	var nearest_name := ""
	var nearest_dist := INF

	for key in solar_system.planets:
		var planet = solar_system.planets[key]
		var dist = player.position.distance_to(planet.position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest_name = planet.name

	return "%s (%.1f M km)" % [nearest_name, nearest_dist]

func format_speed(speed_km_s: float) -> String:
	if speed_km_s >= 299792:  # Speed of light
		return "%.4fc" % (speed_km_s / 299792.0)
	elif speed_km_s >= 1000:
		return "%.1f km/s" % speed_km_s
	elif speed_km_s >= 1:
		return "%.2f km/s" % speed_km_s
	else:
		return "%.1f m/s" % (speed_km_s * 1000)

func format_distance(distance_units: float) -> String:
	var km = distance_units * KM_PER_UNIT
	if km >= 149_600_000:  # 1 AU
		return "%.2f AU" % (km / 149_600_000.0)
	elif km >= 1_000_000:
		return "%.1f M km" % (km / 1_000_000.0)
	else:
		return "%.0f km" % km

func format_time_scale(scale: float) -> String:
	if scale >= 1_000_000:
		return "%.1fM x" % (scale / 1_000_000.0)
	elif scale >= 1000:
		return "%.1fK x" % (scale / 1000.0)
	else:
		return "%.0f x" % scale
