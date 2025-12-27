extends Node2D

# Player spaceship with acceleration-based physics
# Controls: Arrow keys to accelerate, not to set speed directly

# Physics constants
const KM_PER_UNIT := 1_000_000.0  # 1 game unit = 1 million km
const G_ACCEL_KM_S2 := 0.0098  # 1g = 9.8 m/s² = 0.0098 km/s²
const MAX_G := 5.0  # Maximum acceleration in g

# Current state
var velocity_km_s := Vector2.ZERO  # Velocity in km/s
var acceleration_g := 0.0  # Current acceleration magnitude in g
var acceleration_direction := Vector2.ZERO  # Direction of thrust

# Reference to solar system for time scale
@onready var solar_system: Node2D = get_parent()
@onready var thrust_flame: Polygon2D = $ThrustFlame

func _process(delta):
	var time_scale = solar_system.get_time_scale() if solar_system else 1.0
	var scaled_delta = delta * time_scale

	handle_input()
	apply_physics(scaled_delta)
	update_rotation()

func handle_input():
	# Get acceleration direction from input
	acceleration_direction = Vector2.ZERO

	if Input.is_action_pressed("ui_right"):
		acceleration_direction.x += 1
	if Input.is_action_pressed("ui_left"):
		acceleration_direction.x -= 1
	if Input.is_action_pressed("ui_down"):
		acceleration_direction.y += 1
	if Input.is_action_pressed("ui_up"):
		acceleration_direction.y -= 1

	# Normalize direction
	if acceleration_direction.length() > 0:
		acceleration_direction = acceleration_direction.normalized()
		acceleration_g = MAX_G  # Apply max acceleration when thrusting
	else:
		acceleration_g = 0.0  # No thrust = no acceleration (space!)

func apply_physics(scaled_delta: float):
	if acceleration_g > 0:
		# Convert g to km/s² and apply
		var accel_km_s2 = acceleration_g * G_ACCEL_KM_S2

		# Update velocity: v += a * t
		velocity_km_s += acceleration_direction * accel_km_s2 * scaled_delta

	# Update position: convert km/s to game units/s
	# velocity is in km/s, position is in game units (million km)
	# So we divide by KM_PER_UNIT to get units/s
	var velocity_units_per_s = velocity_km_s / KM_PER_UNIT
	position += velocity_units_per_s * scaled_delta

func update_rotation():
	# Rotate ship to face acceleration direction when thrusting, else velocity
	if acceleration_g > 0 and acceleration_direction.length() > 0:
		rotation = acceleration_direction.angle()
	elif velocity_km_s.length() > 0.001:
		rotation = velocity_km_s.angle()

	# Show thrust flame when accelerating
	if thrust_flame:
		thrust_flame.visible = acceleration_g > 0

# Getters for HUD
func get_speed_km_s() -> float:
	return velocity_km_s.length()

func get_velocity_km_s() -> Vector2:
	return velocity_km_s

func get_acceleration_g() -> float:
	return acceleration_g

func get_acceleration_direction() -> Vector2:
	return acceleration_direction
