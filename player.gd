extends Node2D

# Player spaceship with acceleration-based physics
# Controls: W/S for thrust, A/D to rotate, T for trajectory

# Physics constants
const KM_PER_UNIT := 1_000_000.0  # 1 game unit = 1 million km
const G_ACCEL_KM_S2 := 0.0098  # 1g = 9.8 m/s² = 0.0098 km/s²
const MAX_G := 5.0  # Maximum acceleration in g
const ROTATION_SPEED := 2.0  # Radians per second for ship rotation

# Current state
var velocity_km_s := Vector2.ZERO  # Velocity in km/s
var acceleration_g := 0.0  # Current acceleration magnitude in g
var thrust_direction := Vector2.RIGHT  # Direction ship is facing
var show_trajectory := true  # Toggle trajectory line

# Reference to solar system for time scale
@onready var solar_system: Node2D = get_parent()
@onready var thrust_flame: Polygon2D = $ThrustFlame
@onready var retro_flame: Polygon2D = $RetroFlame
@onready var trajectory_line: Line2D = $TrajectoryLine

func _ready():
	# Initialize ship facing direction from rotation
	thrust_direction = Vector2.RIGHT.rotated(rotation)

func _process(delta):
	var time_scale := 1.0
	if solar_system and solar_system.has_method("get_time_scale"):
		time_scale = solar_system.get_time_scale()
	var scaled_delta = delta * time_scale

	handle_rotation(delta)  # Rotation uses real delta, not time-scaled
	handle_thrust()
	apply_physics(scaled_delta)
	update_visuals()
	update_trajectory(time_scale)

func handle_rotation(delta: float):
	# A/D or Left/Right to rotate ship
	var rotate_input := 0.0

	if Input.is_action_pressed("rotate_left"):
		rotate_input -= 1.0
	if Input.is_action_pressed("rotate_right"):
		rotate_input += 1.0

	if rotate_input != 0.0:
		rotation += rotate_input * ROTATION_SPEED * delta
		thrust_direction = Vector2.RIGHT.rotated(rotation)

func handle_thrust():
	acceleration_g = 0.0

	# W or Up = thrust forward (in direction ship faces)
	if Input.is_action_pressed("thrust_forward"):
		acceleration_g = MAX_G
	# S or Down = thrust backward (retro, slow down)
	elif Input.is_action_pressed("thrust_backward"):
		acceleration_g = -MAX_G  # Negative for retrograde

	# Toggle trajectory with T
	if Input.is_action_just_pressed("toggle_trajectory"):
		show_trajectory = !show_trajectory

func apply_physics(scaled_delta: float):
	# Apply thrust acceleration
	if acceleration_g != 0.0:
		# Convert g to km/s² and apply in thrust direction
		var accel_km_s2 = abs(acceleration_g) * G_ACCEL_KM_S2
		var direction = thrust_direction if acceleration_g > 0 else -thrust_direction

		# Update velocity: v += a * t
		velocity_km_s += direction * accel_km_s2 * scaled_delta

	# Apply gravitational acceleration from all bodies
	if solar_system and solar_system.has_method("get_gravity_at"):
		var gravity_accel = solar_system.get_gravity_at(position)
		velocity_km_s += gravity_accel * scaled_delta

	# Update position: convert km/s to game units/s
	var velocity_units_per_s = velocity_km_s / KM_PER_UNIT
	position += velocity_units_per_s * scaled_delta

func update_visuals():
	# Show thrust flame when accelerating forward
	if thrust_flame:
		thrust_flame.visible = acceleration_g > 0
	# Show retro flame when braking
	if retro_flame:
		retro_flame.visible = acceleration_g < 0

func update_trajectory(_time_scale: float):
	if not trajectory_line:
		return

	trajectory_line.visible = show_trajectory
	if not show_trajectory:
		return

	# Predict future positions with gravity simulation
	var points := PackedVector2Array()
	points.append(Vector2.ZERO)  # Start at ship position (local coords)

	var sim_velocity = velocity_km_s
	var sim_position_world = position  # World position for gravity calc
	var sim_position_local = Vector2.ZERO  # Local position for drawing

	# Simulate future trajectory with gravity
	# Need long simulation to see orbital curvature (Earth orbit = 365 days)
	# 20000s per step * 600 steps = 139 days of trajectory
	var step_time := 20000.0  # seconds per simulation step (~5.5 hours)
	var num_steps := 600  # Enough to see significant orbital arc

	for i in range(num_steps):
		# Apply gravity at current simulated position
		if solar_system and solar_system.has_method("get_gravity_at"):
			var gravity_accel = solar_system.get_gravity_at(sim_position_world)
			sim_velocity += gravity_accel * step_time

		# Move based on velocity
		var vel_units = sim_velocity / KM_PER_UNIT
		var delta_pos = vel_units * step_time
		sim_position_world += delta_pos
		sim_position_local += delta_pos

		# Add point every few steps to keep line smooth
		if i % 4 == 0:
			points.append(sim_position_local)

	trajectory_line.points = points

# Getters for HUD
func get_speed_km_s() -> float:
	return velocity_km_s.length()

func get_velocity_km_s() -> Vector2:
	return velocity_km_s

func get_acceleration_g() -> float:
	return acceleration_g

func is_thrusting() -> bool:
	return acceleration_g != 0.0
