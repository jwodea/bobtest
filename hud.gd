extends CanvasLayer

@onready var speed_label: Label = $MarginContainer/VBoxContainer/SpeedLabel
@onready var accel_label: Label = $MarginContainer/VBoxContainer/AccelLabel
@onready var time_label: Label = $MarginContainer/VBoxContainer/TimeLabel
@onready var position_label: Label = $MarginContainer/VBoxContainer/PositionLabel
@onready var nav_label: Label = $MarginContainer/VBoxContainer/NavLabel
@onready var target_label: Label = $MarginContainer/VBoxContainer/TargetLabel

var player: Node2D
var solar_system: Node2D

const KM_PER_UNIT := 1_000_000.0

func _ready():
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
	update_nav_display()
	update_target_display()

func update_speed_display():
	var speed = player.get_speed_km_s()
	speed_label.text = "Speed: " + format_speed(speed)

func update_accel_display():
	var accel = player.get_acceleration_g()
	var is_nav = player.is_navigating() if player.has_method("is_navigating") else false
	if is_nav:
		accel_label.text = "Thrust: %.0fg (active)" % accel
	else:
		accel_label.text = "Thrust: %.0fg (set)" % accel

func update_time_display():
	var time_scale = solar_system.get_time_scale()
	time_label.text = "Time: " + format_time_scale(time_scale)

func update_position_display():
	var pos = player.position
	var distance_from_sun = pos.length()
	position_label.text = "From Sun: " + format_distance(distance_from_sun)

func update_nav_display():
	if player.has_method("get_nav_state_string"):
		var state = player.get_nav_state_string()
		nav_label.text = "Nav: " + state
	else:
		nav_label.text = "Nav: Manual"

func update_target_display():
	if player.has_method("get_target_name"):
		var target = player.get_target_name()
		var eta = player.get_estimated_time() if player.has_method("get_estimated_time") else 0.0
		if target != "None":
			target_label.text = "Target: %s (ETA: %s)" % [target, format_time(eta)]
		else:
			target_label.text = "Target: Click a planet"
	else:
		target_label.text = "Target: None"

func format_speed(speed_km_s: float) -> String:
	if speed_km_s >= 299792:
		return "%.4fc" % (speed_km_s / 299792.0)
	elif speed_km_s >= 1000:
		return "%.1f km/s" % speed_km_s
	elif speed_km_s >= 1:
		return "%.2f km/s" % speed_km_s
	else:
		return "%.1f m/s" % (speed_km_s * 1000)

func format_distance(distance_units: float) -> String:
	var km = distance_units * KM_PER_UNIT
	if km >= 149_600_000:
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

func format_time(seconds: float) -> String:
	if seconds <= 0:
		return "--"
	elif seconds < 60:
		return "%.0fs" % seconds
	elif seconds < 3600:
		return "%.1f min" % (seconds / 60.0)
	elif seconds < 86400:
		return "%.1f hrs" % (seconds / 3600.0)
	else:
		return "%.1f days" % (seconds / 86400.0)
