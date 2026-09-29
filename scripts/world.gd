extends Node3D

var navigation := AStarGrid2D.new()
var rng := RandomNumberGenerator.new()
var materials: Dictionary = {}
var muster: Node3D
var depot := Vector3(-25, 0, 8)
var sites: Array[Dictionary] = [
	{"name": "ЗАБРОШЕННЫЙ СКЛАД", "position": Vector3(34, 0, 2), "stock": 120, "kind": "materials"},
	{"name": "ЛЕСОПИЛКА", "position": Vector3(16, 0, -36), "stock": 80, "kind": "materials"},
	{"name": "ЛАГЕРЬ ВЫЖИВШИХ", "position": Vector3(-35, 0, 37), "stock": 4, "kind": "people"}
]

func material(color: Color, emission: bool = false) -> StandardMaterial3D:
	var key := str(color) + str(emission)
	if materials.has(key):
		return materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.88
	if emission:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 1.5
	materials[key] = m
	return m

func box(parent: Node3D, at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = material(color)
	parent.add_child(mesh)
	mesh.position = at
	return mesh

func cylinder(parent: Node3D, at: Vector3, radius: float, height: float, color: Color, top: float = -1.0) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := CylinderMesh.new()
	shape.bottom_radius = radius
	shape.top_radius = radius if top < 0 else top
	shape.height = height
	shape.radial_segments = 8
	mesh.mesh = shape
	mesh.material_override = material(color)
	parent.add_child(mesh)
	mesh.position = at
	return mesh

func caption(at: Vector3, text: String, tint := Color("ded8b3"), font_size: int = 36) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = font_size
	label.pixel_size = 0.022
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = tint
	label.outline_modulate = Color("17211c")
	label.outline_size = 9
	label.no_depth_test = true
	add_child(label)
	label.position = at
	return label

func to_cell(at: Vector3) -> Vector2i:
	return Vector2i(clampi(roundi((at.x + 80.0) / 2.0), 0, 80), clampi(roundi((at.z + 80.0) / 2.0), 0, 80))

func obstacle(at: Vector3, size: Vector3) -> void:
	var start := to_cell(at - size / 2.0 - Vector3(0.7, 0, 0.7))
	var end := to_cell(at + size / 2.0 + Vector3(0.7, 0, 0.7))
	for x in range(start.x, end.x + 1):
		for y in range(start.y, end.y + 1):
			navigation.set_point_solid(Vector2i(x, y))

func route(from: Vector3, to: Vector3) -> PackedVector3Array:
	var result := PackedVector3Array()
	var end := to_cell(to)
	if navigation.is_point_solid(end):
		return result
	var points := navigation.get_point_path(to_cell(from), end)
	for p in points:
		result.append(Vector3(p.x, 0, p.y))
	return result

func nearest_free(at: Vector3) -> Vector3:
	var cell := to_cell(at)
	for radius in range(0, 5):
		for x in range(-radius, radius + 1):
			for y in range(-radius, radius + 1):
				var test := cell + Vector2i(x, y)
				if navigation.is_in_boundsv(test) and not navigation.is_point_solid(test):
					var p := navigation.get_point_position(test)
					return Vector3(p.x, 0, p.y)
	return at

func _ready() -> void:
	rng.seed = 29092026
	navigation.region = Rect2i(0, 0, 81, 81)
	navigation.cell_size = Vector2(2, 2)
	navigation.offset = Vector2(-80, -80)
	navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	navigation.update()
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("889b9c")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b5c3cb")
	env.ambient_light_energy = 0.32
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color("97aaa2")
	env.fog_density = 0.0018
	environment.environment = env
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_color = Color("ffe0ae")
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 220
	add_child(sun)
	box(self, Vector3(0, -0.5, 0), Vector3(164, 1, 164), Color("56664a"))
	# A single continuous map. Region borders have no collision.
	for i in range(85):
		var p := Vector3(rng.randf_range(-79, 79), 0.015, rng.randf_range(-79, 79))
		cylinder(self, p, rng.randf_range(2, 8), 0.025, Color("5c6c4d") if i % 2 else Color("607052"))
	box(self, Vector3(0, 0.045, 8), Vector3(150, 0.08, 6), Color("77756a"))
	box(self, Vector3(15, 0.04, -15), Vector3(4.5, 0.07, 44), Color("77756a"))
	box(self, Vector3(-34, 0.04, 24), Vector3(4.5, 0.07, 34), Color("77756a"))
	for i in range(32):
		box(self, Vector3(-72 + i * 4.5, 0.09, 8), Vector3(1.7, 0.03, 0.11), Color("b8b6a0"))
	for i in range(25):
		box(self, Vector3(0, 0.08, -73 + i * 6), Vector3(0.12, 0.02, 1.8), Color("9ba585"))
	caption(Vector3(-36, 0.2, -25), "ТИХАЯ НИЗИНА", Color("a9bb93"), 30)
	caption(Vector3(38, 0.2, -25), "ПРОМЫШЛЕННАЯ ОКРАИНА", Color("b0b292"), 30)
	build_home()
	building(Vector3(36, 0, -9), Vector3(15, 6, 12), Color("778580"), Color("685349"))
	for x in [31.0, 38.0, 42.0]:
		box(self, Vector3(x, 1.7, -2.9), Vector3(3, 3.4, 0.16), Color("3c4949"))
	for i in range(11):
		var p := Vector3(27 + (i % 4) * 2.0, 0, -17 - floori(i / 4.0) * 2)
		box(self, p + Vector3(0, 0.6, 0), Vector3(1.6, 1.2, 1.6), Color("8a7354"))
	building(Vector3(17, 0, -44), Vector3(10, 3.8, 7), Color("6e715c"), Color("535b51"))
	for i in range(8):
		var log_mesh := cylinder(self, Vector3(24 + (i % 3), 0.7 + floori(i / 3.0) * 0.6, -38), 0.45, 6, Color("746048"))
		log_mesh.rotation_degrees.x = 90
	for p in [Vector3(-41, 0, 40), Vector3(-31, 0, 43)]:
		tent(p)
	for site in sites:
		caption(site.position + Vector3(0, 4, 0), site.name, Color("dfd5ad"), 30)
		cylinder(self, site.position + Vector3(0, 0.1, 0), 2, 0.1, Color("9c8854"))
	for i in range(250):
		var p := Vector3(rng.randf_range(-77, 77), 0, rng.randf_range(-77, 77))
		if absf(p.z - 8) < 7 or absf(p.x - 15) < 6 or absf(p.x + 34) < 7:
			continue
		if p.distance_to(Vector3(-32, 0, -2)) < 25 or p.distance_to(Vector3(36, 0, -8)) < 19:
			continue
		if p.distance_to(Vector3(17, 0, -42)) < 15 or p.distance_to(Vector3(-35, 0, 40)) < 13:
			continue
		tree(p, rng.randf_range(0.8, 1.7))
	for i in range(80):
		var p := Vector3(rng.randf_range(-77, 77), 0.25, rng.randf_range(-77, 77))
		if absf(p.z - 8) < 7 or p.distance_to(Vector3(-32, 0, -2)) < 25:
			continue
		var stone := cylinder(self, p, rng.randf_range(0.4, 1.0), rng.randf_range(0.4, 1.3), Color("7b8276"), 0.3)
		stone.rotation_degrees.z = rng.randf_range(-15, 15)
	caption(Vector3(-34, 7, -7), "ПЕРВОЕ УБЕЖИЩЕ", Color("e5e7c3"), 40)

func building(at: Vector3, size: Vector3, wall: Color, roof: Color) -> void:
	box(self, at + Vector3(0, 0.15, 0), size * Vector3(1.1, 0, 1.1) + Vector3(0, 0.3, 0), Color("858378"))
	box(self, at + Vector3(0, size.y / 2, 0), size, wall)
	var roof_mesh := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(size.x + 1, 2.2, size.z + 1)
	roof_mesh.mesh = prism
	roof_mesh.material_override = material(roof)
	add_child(roof_mesh)
	roof_mesh.position = at + Vector3(0, size.y + 1.1, 0)
	for x in [-0.3, 0.3]:
		box(self, at + Vector3(size.x * x, size.y * 0.55, size.z / 2 + 0.03), Vector3(size.x * 0.2, size.y * 0.35, 0.12), Color("c4ba85"))
	obstacle(at, size)

func build_home() -> void:
	box(self, Vector3(-32, 0.03, -3), Vector3(32, 0.05, 29), Color("7b7b61"))
	building(Vector3(-35, 0, -7), Vector3(11, 4.1, 8), Color("b3ab8c"), Color("6b5147"))
	box(self, Vector3(-35, 1.1, -2.94), Vector3(1.5, 2.2, 0.16), Color("423d33"))
	box(self, Vector3(-35, 0.3, -1.7), Vector3(5, 0.6, 2), Color("9b947e"))
	box(self, Vector3(-38, 5, -8), Vector3(0.9, 2.2, 0.9), Color("776653"))
	for z in range(-18, 19, 3):
		if z > 4 and z < 12:
			continue
		fence(Vector3(-17, 0, z), true)
	for x in range(-47, -16, 3):
		fence(Vector3(x, 0, -19), false)
	for z in [4.0, 12.0]:
		box(self, Vector3(-17, 1.8, z), Vector3(0.6, 3.6, 0.6), Color("695d46"))
		var light_mesh := box(self, Vector3(-17, 3.7, z), Vector3(0.45, 0.4, 0.45), Color("ffda91"))
		light_mesh.material_override = material(Color("ffcf78"), true)
	for i in range(5):
		box(self, Vector3(-43 + i * 1.8, 0.12, -15), Vector3(1.2, 0.2, 5), Color("514d34"))
		for j in range(5):
			cylinder(self, Vector3(-43 + i * 1.8, 0.45, -17 + j), 0.35, 0.7, Color("71824c"), 0.1)
	for p in [Vector3(-43, 0, 3), Vector3(-43, 0, 10)]:
		tent(p)
	for i in range(4):
		box(self, Vector3(-30 + i * 1.5, 0.55, 1), Vector3(1.2, 1.1, 1.2), Color("97805c"))
	cylinder(self, depot + Vector3(0, 0.08, 0), 3, 0.1, Color("858a63"))
	caption(depot + Vector3(0, 0.6, 0), "РАЗГРУЗКА", Color("c8cfa7"), 22)
	muster = Node3D.new()
	add_child(muster)
	muster.position = Vector3(-21, 0, -1)
	box(muster, Vector3(0, 0.06, 0), Vector3(6, 0.12, 4), Color("a8a579"))
	caption(Vector3(-21, 1.2, -1), "СБОРНЫЙ ПУНКТ\nместо строительства", Color("c0cba7"), 23).name = "MusterCaption"

func finish_muster() -> void:
	for x in [-2.6, 2.6]:
		for z in [-1.5, 1.5]:
			box(muster, Vector3(x, 1.5, z), Vector3(0.18, 3, 0.18), Color("76664e"))
	box(muster, Vector3(0, 3, 0), Vector3(6.2, 0.25, 4.2), Color("536f60"))
	box(muster, Vector3(0, 0.9, 0), Vector3(2.8, 0.2, 1.2), Color("89734e"))
	box(muster, Vector3(0, 1.02, 0), Vector3(1.7, 0.04, 0.8), Color("c5c29c"))
	get_node("MusterCaption").text = "СБОРНЫЙ ПУНКТ"
	get_node("MusterCaption").position.y = 4.4
	obstacle(muster.position, Vector3(6, 1, 4))

func tent(at: Vector3) -> void:
	var mesh := cylinder(self, at + Vector3(0, 1.25, 0), 2.5, 2.5, Color("9c9a71"), 0)
	mesh.mesh.radial_segments = 4
	mesh.rotation_degrees.y = 45
	box(self, at + Vector3(0, 0.6, 1.25), Vector3(0.8, 1.2, 0.05), Color("414b39"))
	obstacle(at, Vector3(3, 2, 3))

func fence(at: Vector3, vertical: bool) -> void:
	box(self, at + Vector3(0, 0.9, 0), Vector3(0.16, 1.5, 2.9) if vertical else Vector3(2.9, 1.5, 0.16), Color("77765d"))
	box(self, at + Vector3(0, 1.1, 0), Vector3(0.28, 2.2, 0.28), Color("5a5847"))
	obstacle(at, Vector3(0.4, 1, 2.5) if vertical else Vector3(2.5, 1, 0.4))

func tree(at: Vector3, scale_factor: float) -> void:
	var root := Node3D.new()
	add_child(root)
	root.position = at
	root.scale = Vector3.ONE * scale_factor
	cylinder(root, Vector3(0, 1.8, 0), 0.23, 3.6, Color("66563e"))
	var color := Color("354f40") if rng.randf() > 0.5 else Color("42604a")
	cylinder(root, Vector3(0, 4, 0), 2.1, 4.5, color, 0)
	cylinder(root, Vector3(0, 5.7, 0), 1.5, 3.6, color.lightened(0.06), 0)
	obstacle(at, Vector3(0.8, 1, 0.8))
