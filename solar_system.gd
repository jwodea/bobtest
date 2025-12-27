extends Node2D

# Solar System Simulation with Realistic Scales
# Distance: 1 game unit = 1 million km
# Speed: tracked in km/s internally
# Time: adjustable time scale for playability

# Physical constants
const KM_PER_UNIT := 1_000_000.0  # 1 game unit = 1 million km
const G_ACCEL := 0.0098  # 9.8 m/s² = 0.0098 km/s²
const MAX_G := 5.0  # Maximum 5g acceleration

# Planet data: [distance_million_km, radius_km, color, name, GM_km3_s2]
# GM (gravitational parameter) in km³/s² - this is G * Mass
const PLANET_DATA := {
	"sun": [0, 696340, Color(1.0, 0.9, 0.2), "Sun", 1.327e11],
	"mercury": [57.9, 2440, Color(0.7, 0.7, 0.7), "Mercury", 2.203e4],
	"venus": [108.2, 6052, Color(0.9, 0.8, 0.5), "Venus", 3.249e5],
	"earth": [149.6, 6371, Color(0.2, 0.5, 1.0), "Earth", 3.986e5],
	"mars": [227.9, 3390, Color(0.9, 0.4, 0.2), "Mars", 4.283e4],
	"jupiter": [778.5, 69911, Color(0.9, 0.7, 0.5), "Jupiter", 1.267e8],
	"saturn": [1432.0, 58232, Color(0.9, 0.8, 0.6), "Saturn", 3.793e7],
	"uranus": [2867.0, 25362, Color(0.6, 0.8, 0.9), "Uranus", 5.794e6],
	"neptune": [4515.0, 24622, Color(0.3, 0.4, 0.9), "Neptune", 6.837e6]
}

# Store GM values for quick lookup (converted for our unit system)
# Since distance is in million km (10^6 km), we need GM / (10^6)^2 = GM / 10^12
# This gives acceleration in km/s² when dividing by r² in game units
var planet_gm := {}  # key -> GM in adjusted units

# Time scale: 1 = real time, higher = faster
var time_scale := 10000.0  # Start at 10,000x to make it playable
const MIN_TIME_SCALE := 1.0
const MAX_TIME_SCALE := 10_000_000.0

var planets := {}

func _ready():
	create_planets()

func create_planets():
	for key in PLANET_DATA:
		var data = PLANET_DATA[key]
		var distance = data[0]  # in million km = game units
		var radius_km = data[1]
		var color = data[2]
		var planet_name = data[3]
		var gm = data[4]  # GM in km³/s²

		var planet = create_planet_node(planet_name, distance, radius_km, color)
		add_child(planet)
		planets[key] = planet

		# Store GM converted for our unit system
		# a = GM / r² where r is in game units (million km)
		# r_km = r_game * 10^6, so r² in km² = r_game² * 10^12
		# a = GM / (r_game² * 10^12) = (GM / 10^12) / r_game²
		planet_gm[key] = gm / 1e12

func create_planet_node(planet_name: String, distance: float, radius_km: float, color: Color) -> Node2D:
	var planet = Node2D.new()
	planet.name = planet_name

	# Position based on distance (place planets along x-axis initially)
	# Randomize angle for variety
	var angle = randf() * TAU
	if planet_name == "Sun":
		angle = 0
		distance = 0
	planet.position = Vector2(cos(angle), sin(angle)) * distance

	# Create visual representation
	var visual = Polygon2D.new()
	visual.name = "Visual"

	# Scale radius for visibility (actual scale would be invisible)
	# Sun: show at reasonable size, planets: exaggerate for visibility
	var display_radius: float
	if planet_name == "Sun":
		display_radius = 50.0  # Sun is visible but not overwhelming
	else:
		# Exaggerate planet sizes for visibility (min 5 pixels, max 30)
		display_radius = clamp(radius_km / 5000.0, 5.0, 30.0)

	# Create circle polygon
	var points := PackedVector2Array()
	var segments := 32
	for i in range(segments):
		var a = i * TAU / segments
		points.append(Vector2(cos(a), sin(a)) * display_radius)
	visual.polygon = points
	visual.color = color

	planet.add_child(visual)

	# Add label
	var label = Label.new()
	label.text = planet_name
	label.position = Vector2(-display_radius, -display_radius - 20)
	label.add_theme_font_size_override("font_size", 14)
	planet.add_child(label)

	return planet

func _process(_delta):
	# Time scale controls
	if Input.is_action_just_pressed("time_faster"):
		time_scale = clamp(time_scale * 10.0, MIN_TIME_SCALE, MAX_TIME_SCALE)
	if Input.is_action_just_pressed("time_slower"):
		time_scale = clamp(time_scale / 10.0, MIN_TIME_SCALE, MAX_TIME_SCALE)

func get_time_scale() -> float:
	return time_scale

# Calculate total gravitational acceleration at a position (in km/s²)
func get_gravity_at(pos: Vector2) -> Vector2:
	var total_accel := Vector2.ZERO

	for key in planets:
		var planet = planets[key]
		var gm = planet_gm[key]

		# Vector from position to planet
		var to_planet = planet.position - pos
		var distance_sq = to_planet.length_squared()

		# Avoid division by zero / extreme values when very close
		if distance_sq < 0.0001:
			continue

		# Gravitational acceleration: a = GM / r²
		# Direction: towards the planet
		var accel_magnitude = gm / distance_sq
		var direction = to_planet.normalized()

		total_accel += direction * accel_magnitude

	return total_accel

func format_distance(distance_units: float) -> String:
	var km = distance_units * KM_PER_UNIT
	if km >= 149_600_000:  # 1 AU
		return "%.2f AU" % (km / 149_600_000.0)
	elif km >= 1_000_000:
		return "%.1f M km" % (km / 1_000_000.0)
	else:
		return "%.0f km" % km

func format_speed(speed_km_s: float) -> String:
	if speed_km_s >= 299792:  # Speed of light
		return "%.4f c" % (speed_km_s / 299792.0)
	elif speed_km_s >= 1000:
		return "%.1f km/s" % speed_km_s
	elif speed_km_s >= 1:
		return "%.2f km/s" % speed_km_s
	else:
		return "%.1f m/s" % (speed_km_s * 1000)
