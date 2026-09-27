extends Node3D
## Repeating set piece for the Neon Avenue route.

const SECTION_LENGTH := 20.0

const CONCRETE := Color(0.24, 0.25, 0.39)
const SHOULDER := Color(0.075, 0.10, 0.19)
const BUILDING_COLORS := [
	Color(0.19, 0.20, 0.37),
	Color(0.15, 0.25, 0.38),
	Color(0.27, 0.17, 0.37),
]
const WINDOW_COLORS := [Color(0.16, 0.78, 1.0), Color(1.0, 0.37, 0.72)]

var _section_index := 0

func _ready() -> void:
	_section_index = absi(int(round(position.z / SECTION_LENGTH)))
	_style_road()
	_build_sidewalks()
	_build_lane_markers()
	_build_neon_edges()
	_build_street_lamps()
	if _section_index % 2 == 0:
		_build_tree((-1.0 if _section_index % 4 == 0 else 1.0) * 10.2, 0.0)
	if _section_index % 3 == 0:
		_build_city_facade((-1.0 if _section_index % 2 == 0 else 1.0) * 15.2, 0.0)

func _style_road() -> void:
	var mesh_node := get_node_or_null("Mesh") as MeshInstance3D
	if mesh_node:
		StyleKit.apply_to_mesh(mesh_node, StyleKit.PALETTE["road"], {
			"outline_width": 0.0,
			"base_glow": 0.01,
		})

func _build_sidewalks() -> void:
	for side in [-1.0, 1.0]:
		_add_box(Vector3(side * 10.6, -0.02, 0.0), Vector3(9.3, 0.12, SECTION_LENGTH), SHOULDER)
		_add_box(Vector3(side * 5.75, 0.055, 0.0), Vector3(1.35, 0.19, SECTION_LENGTH), CONCRETE)
		_add_box(Vector3(side * 5.05, 0.18, 0.0), Vector3(0.08, 0.05, SECTION_LENGTH), Color(0.08, 0.82, 0.94), 0.0, 0.45)

		# Short paving cuts make the edge feel built instead of painted on.
		for i in range(5):
			_add_box(Vector3(side * 5.75, 0.157, -8.0 + i * 4.0), Vector3(1.18, 0.018, 0.035), Color(0.37, 0.38, 0.51))

func _build_lane_markers() -> void:
	for x in [-1.5, 1.5]:
		_add_box(Vector3(x, 0.125, 0.0), Vector3(0.045, 0.025, SECTION_LENGTH), Color(0.54, 0.62, 0.78))
	for i in range(-4, 5):
		_add_box(Vector3(0.0, 0.16, float(i) * 2.2), Vector3(0.16, 0.035, 1.1), Color(1.0, 0.79, 0.36), 0.0, 0.22)

func _build_neon_edges() -> void:
	for side in [-1.0, 1.0]:
		_add_box(Vector3(side * 5.02, 0.24, 0.0), Vector3(0.12, 0.34, SECTION_LENGTH), Color(0.05, 0.78, 0.94), 0.0, 0.4)

func _build_street_lamps() -> void:
	# The alternating placement gives the route a steady cadence without clutter.
	var side := -1.0 if _section_index % 2 == 0 else 1.0
	var x := side * 6.7
	var accent: Color = WINDOW_COLORS[_section_index % WINDOW_COLORS.size()]
	_add_cylinder(Vector3(x, 2.05, 0.0), 0.075, 4.1, Color(0.16, 0.18, 0.28))
	_add_box(Vector3(x - side * 0.35, 4.0, 0.0), Vector3(0.78, 0.09, 0.13), Color(0.2, 0.22, 0.34))
	_add_box(Vector3(x - side * 0.35, 3.92, 0.0), Vector3(0.36, 0.035, 0.22), accent, 0.0, 0.65)
	_add_box(Vector3(x, 0.28, 0.0), Vector3(0.34, 0.22, 0.38), Color(0.17, 0.19, 0.3))

func _build_tree(x: float, z: float) -> void:
	# Three clean low-poly tiers replace the old wobbling sphere clusters.
	var planter := _add_box(Vector3(x, 0.2, z), Vector3(1.65, 0.4, 1.65), Color(0.20, 0.22, 0.34))
	planter.rotation_degrees.y = 45.0
	_add_cylinder(Vector3(x, 1.45, z), 0.17, 2.5, Color(0.38, 0.24, 0.23))
	_add_cone(Vector3(x, 2.4, z), 1.05, 1.8, Color(0.16, 0.52, 0.42))
	_add_cone(Vector3(x, 3.25, z), 0.76, 1.5, Color(0.20, 0.67, 0.51))
	_add_cone(Vector3(x, 4.0, z), 0.48, 1.1, Color(0.34, 0.78, 0.58))

func _build_city_facade(x: float, z: float) -> void:
	var palette_index := _section_index % BUILDING_COLORS.size()
	var wall: Color = BUILDING_COLORS[palette_index]
	var height := 6.0 + float((_section_index * 7) % 5)
	var width := 4.4
	var depth := 7.5
	var side := signf(x)
	var center := Vector3(x, height * 0.5, z)
	_add_box(center, Vector3(width, height, depth), wall)
	_add_box(Vector3(x, height + 0.12, z), Vector3(width + 0.35, 0.24, depth + 0.35), Color(0.24, 0.27, 0.42))
	# Recessed-looking window bands on the face toward the road.
	var facade_x := x - side * (width * 0.5 + 0.025)
	var accent: Color = WINDOW_COLORS[palette_index % WINDOW_COLORS.size()]
	for floor_index in range(1, int(height / 1.6)):
		var y := float(floor_index) * 1.6
		for col in range(3):
			var z_offset := -2.2 + float(col) * 2.2
			_add_box(Vector3(facade_x, y, z + z_offset), Vector3(0.045, 0.68, 1.15), Color(0.13, 0.21, 0.34))
			_add_box(Vector3(facade_x - side * 0.03, y + 0.02, z + z_offset), Vector3(0.035, 0.045, 0.9), accent, 0.0, 0.22)
	_add_box(Vector3(facade_x - side * 0.04, height * 0.5, z - depth * 0.5 + 0.45), Vector3(0.07, height * 0.68, 0.12), accent, 0.0, 0.34)

func _add_box(pos: Vector3, size: Vector3, color: Color, outline: float = 0.0, emission: float = 0.0) -> MeshInstance3D:
	var mesh_node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_node.mesh = mesh
	mesh_node.position = pos
	add_child(mesh_node)
	StyleKit.apply_to_mesh(mesh_node, color, {
		"outline_width": outline,
		"emission_strength": emission,
		"emission_color": color,
		"base_glow": 0.015,
	})
	return mesh_node

func _add_cylinder(pos: Vector3, radius: float, height: float, color: Color) -> void:
	var mesh_node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.88
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	mesh_node.mesh = mesh
	mesh_node.position = pos
	add_child(mesh_node)
	StyleKit.apply_to_mesh(mesh_node, color, {"outline_width": 0.0, "base_glow": 0.01})

func _add_cone(pos: Vector3, radius: float, height: float, color: Color) -> void:
	var mesh_node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 7
	mesh_node.mesh = mesh
	mesh_node.position = pos
	add_child(mesh_node)
	StyleKit.apply_to_mesh(mesh_node, color, {"outline_width": 0.015, "base_glow": 0.01})
