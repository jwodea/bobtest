extends Node2D

# Player spaceship with autopilot navigation
# Click planets to target, ship automatically navigates

# Physics constants
const KM_PER_UNIT := 1_000_000.0  # 1 game unit = 1 million km
const G_ACCEL_KM_S2 := 0.0098  # 1g = 9.8 m/s² = 0.0098 km/s²

# Navigation state
enum NavState { IDLE, TARGETING, ACCELERATING, COASTING, DECELERATING, ARRIVING }
var nav_state := NavState.IDLE
var target_body: Node2D = null  # Target planet/body
var target_position := Vector2.ZERO  # Where we're going
var target_orbit_velocity := Vector2.ZERO  # Velocity to match at destination

# Acceleration setting (1-5g)
var acceleration_g := 1.0
const MIN_ACCEL := 1.0
const MAX_ACCEL := 5.0

# Current state
var velocity_km_s := Vector2.ZERO  # Velocity in km/s
var thrust_direction := Vector2.RIGHT  # Direction ship is facing
var is_thrusting := false
var show_trajectory := true

# Transfer calculation results
var burn_direction := Vector2.ZERO
var halfway_point := Vector2.ZERO
var estimated_travel_time := 0.0

# Reference to solar system
@onready var solar_system: Node2D = get_parent()
@onready var thrust_flame: Polygon2D = $ThrustFlame
@onready var retro_flame: Polygon2D = $RetroFlame
@onready var trajectory_line: Line2D = get_node_or_null("../TrajectoryLine")

func _ready():
	thrust_direction = Vector2.RIGHT.rotated(rotation)

func _process(delta):
	var time_scale := 1.0
	if solar_system and solar_system.has_method("get_time_scale"):
		time_scale = solar_system.get_time_scale()
	var scaled_delta = delta * time_scale

	handle_input()
	update_navigation(scaled_delta)
	apply_physics(scaled_delta)
	update_visuals()
	update_trajectory()

func handle_input():
	# Acceleration selection (1-5 keys)
	if Input.is_action_just_pressed("ui_text_delete"):  # 1 key
		acceleration_g = 1.0
	for i in range(1, 6):
		if Input.is_key_pressed(KEY_1 + i - 1):
			acceleration_g = float(i)
			break

	# Toggle trajectory with T
	if Input.is_action_just_pressed("toggle_trajectory"):
		show_trajectory = !show_trajectory

	# Start transfer with Space
	if Input.is_action_just_pressed("ui_accept"):
		if nav_state == NavState.TARGETING and target_body:
			start_transfer()

	# Cancel with Escape
	if Input.is_action_just_pressed("ui_cancel"):
		cancel_navigation()

func _unhandled_input(event):
	# Click to select target
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var click_pos = get_global_mouse_position()
		try_select_target(click_pos)

func try_select_target(click_pos: Vector2):
	if not solar_system or not solar_system.planets:
		return

	# Find closest planet to click
	var closest_planet: Node2D = null
	var closest_dist := INF

	for key in solar_system.planets:
		var planet = solar_system.planets[key]
		var dist = click_pos.distance_to(planet.position)
		# Use a generous click radius based on zoom level
		var click_radius = 100.0 / get_viewport().get_camera_2d().zoom.x if get_viewport().get_camera_2d() else 100.0
		if dist < closest_dist and dist < click_radius:
			closest_dist = dist
			closest_planet = planet

	if closest_planet:
		select_target(closest_planet)

func select_target(planet: Node2D):
	target_body = planet
	target_position = planet.position
	nav_state = NavState.TARGETING
	calculate_transfer()

func calculate_transfer():
	if not target_body:
		return

	# Calculate transfer parameters
	var to_target = target_position - position
	var distance = to_target.length()

	# Simple brachistochrone transfer: accelerate halfway, decelerate halfway
	halfway_point = position + to_target * 0.5

	# Time = 2 * sqrt(distance / acceleration)
	# Convert acceleration to game units: g * 0.0098 km/s² / 1e6 = units/s²
	var accel_units = acceleration_g * G_ACCEL_KM_S2 / KM_PER_UNIT
	if accel_units > 0:
		estimated_travel_time = 2.0 * sqrt(distance / accel_units)

	# Calculate orbital velocity at destination (for orbit insertion)
	# v = sqrt(GM_sun / r)
	var sun_gm = 1.327e11 / 1e12  # Scaled GM
	var target_dist_from_sun = target_position.length()
	if target_dist_from_sun > 0.1:
		var orbital_speed = sqrt(sun_gm / target_dist_from_sun) # km/s
		# Orbital velocity is perpendicular to sun direction
		var sun_dir = target_position.normalized()
		target_orbit_velocity = Vector2(-sun_dir.y, sun_dir.x) * orbital_speed

func start_transfer():
	if nav_state != NavState.TARGETING:
		return

	nav_state = NavState.ACCELERATING
	burn_direction = (target_position - position).normalized()

func cancel_navigation():
	nav_state = NavState.IDLE
	target_body = null
	is_thrusting = false

func update_navigation(scaled_delta: float):
	if target_body:
		# Update target position (planets may have moved... though they don't yet)
		target_position = target_body.position
		calculate_transfer()

	match nav_state:
		NavState.IDLE:
			is_thrusting = false

		NavState.TARGETING:
			is_thrusting = false
			# Just showing preview, not moving yet

		NavState.ACCELERATING:
			# Burn towards target
			var to_target = target_position - position
			burn_direction = to_target.normalized()

			# Check if we've passed halfway point
			var to_halfway = halfway_point - position
			if to_halfway.dot(burn_direction) <= 0:
				nav_state = NavState.DECELERATING

			# Apply thrust
			is_thrusting = true
			thrust_direction = burn_direction
			rotation = thrust_direction.angle()

		NavState.DECELERATING:
			# Burn against velocity to slow down
			var to_target = target_position - position
			burn_direction = -velocity_km_s.normalized() if velocity_km_s.length() > 0.1 else -to_target.normalized()

			# Check if we're close and slow enough
			var distance_to_target = to_target.length()
			var speed = velocity_km_s.length()

			# Calculate stopping distance at current speed and acceleration
			var accel = acceleration_g * G_ACCEL_KM_S2
			var stopping_time = speed / accel if accel > 0 else INF

			if distance_to_target < 5.0 and speed < 50.0:
				# Close enough and slow enough - try to match orbit
				nav_state = NavState.ARRIVING
			elif distance_to_target < 1.0:
				# Very close - stop
				nav_state = NavState.ARRIVING

			is_thrusting = true
			thrust_direction = burn_direction
			rotation = thrust_direction.angle()

		NavState.ARRIVING:
			# Match orbital velocity
			var velocity_diff = target_orbit_velocity - velocity_km_s
			if velocity_diff.length() > 1.0:
				burn_direction = velocity_diff.normalized()
				is_thrusting = true
				thrust_direction = burn_direction
				rotation = thrust_direction.angle()

				# Check if we've matched velocity
				if velocity_diff.length() < 5.0:
					nav_state = NavState.IDLE
					is_thrusting = false
			else:
				nav_state = NavState.IDLE
				is_thrusting = false

func apply_physics(scaled_delta: float):
	# Apply thrust acceleration
	if is_thrusting:
		var accel_km_s2 = acceleration_g * G_ACCEL_KM_S2
		velocity_km_s += thrust_direction * accel_km_s2 * scaled_delta

	# Apply gravitational acceleration from all bodies
	if solar_system and solar_system.has_method("get_gravity_at"):
		var gravity_accel = solar_system.get_gravity_at(position)
		velocity_km_s += gravity_accel * scaled_delta

	# Update position
	var velocity_units_per_s = velocity_km_s / KM_PER_UNIT
	position += velocity_units_per_s * scaled_delta

func update_visuals():
	if thrust_flame:
		thrust_flame.visible = is_thrusting and thrust_direction.dot(Vector2.RIGHT.rotated(rotation)) > 0
	if retro_flame:
		retro_flame.visible = is_thrusting and thrust_direction.dot(Vector2.RIGHT.rotated(rotation)) < 0

func update_trajectory():
	if not trajectory_line:
		return

	trajectory_line.visible = show_trajectory
	if not show_trajectory:
		return

	var points := PackedVector2Array()
	points.append(position)

	var sim_velocity = velocity_km_s
	var sim_position = position
	var sim_state = nav_state
	var sim_burn_dir = burn_direction

	var step_time := 10000.0
	var num_steps := 800

	for i in range(num_steps):
		# Simulate thrust based on nav state
		if sim_state == NavState.ACCELERATING or sim_state == NavState.DECELERATING:
			var accel_km_s2 = acceleration_g * G_ACCEL_KM_S2

			if sim_state == NavState.ACCELERATING:
				sim_burn_dir = (target_position - sim_position).normalized()
				var to_halfway = halfway_point - sim_position
				if to_halfway.dot(sim_burn_dir) <= 0:
					sim_state = NavState.DECELERATING

			if sim_state == NavState.DECELERATING:
				sim_burn_dir = -sim_velocity.normalized() if sim_velocity.length() > 0.1 else Vector2.ZERO

				var dist_to_target = (target_position - sim_position).length()
				if dist_to_target < 5.0 and sim_velocity.length() < 50.0:
					sim_state = NavState.ARRIVING

			sim_velocity += sim_burn_dir * accel_km_s2 * step_time

		# Apply gravity
		if solar_system and solar_system.has_method("get_gravity_at"):
			var gravity_accel = solar_system.get_gravity_at(sim_position)
			sim_velocity += gravity_accel * step_time

		# Move
		var vel_units = sim_velocity / KM_PER_UNIT
		sim_position += vel_units * step_time

		if i % 4 == 0:
			points.append(sim_position)

	trajectory_line.points = points

# Getters for HUD
func get_speed_km_s() -> float:
	return velocity_km_s.length()

func get_velocity_km_s() -> Vector2:
	return velocity_km_s

func get_acceleration_g() -> float:
	return acceleration_g

func get_nav_state() -> NavState:
	return nav_state

func get_nav_state_string() -> String:
	match nav_state:
		NavState.IDLE: return "Idle"
		NavState.TARGETING: return "Target Selected"
		NavState.ACCELERATING: return "Accelerating"
		NavState.COASTING: return "Coasting"
		NavState.DECELERATING: return "Decelerating"
		NavState.ARRIVING: return "Orbital Insertion"
		_: return "Unknown"

func get_target_name() -> String:
	return target_body.name if target_body else "None"

func get_estimated_time() -> float:
	return estimated_travel_time

func is_navigating() -> bool:
	return nav_state in [NavState.ACCELERATING, NavState.DECELERATING, NavState.ARRIVING]
