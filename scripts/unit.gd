extends Node3D

var world: Node3D
var kind := "resident"
var health := 100.0
var path := PackedVector3Array()
var speed := 4.0
var selected := false
var ring: MeshInstance3D
var body: Node3D
var gait := 0.0
var cooldown := 0.0
var repath := 0.0
var last_destination := Vector3.ZERO
var has_destination := false
var alive := true

func setup(map: Node3D, type: String, at: Vector3, color: Color) -> void:
	world = map
	kind = type
	position = at
	body = Node3D.new()
	add_child(body)
	if kind == "truck":
		speed = 8.0
		health = 240
		world.box(body, Vector3(0, 0.95, 0), Vector3(2.4, 0.5, 4.5), Color("35463c"))
		world.box(body, Vector3(0, 1.85, -1.25), Vector3(2.3, 1.5, 1.8), color)
		world.box(body, Vector3(0, 2.0, -2.17), Vector3(1.9, 0.6, 0.04), Color("97bbb3"))
		world.box(body, Vector3(0, 1.15, -2.05), Vector3(2.3, 0.35, 0.6), color)
		world.box(body, Vector3(0, 1.26, 0.8), Vector3(2.1, 0.13, 2.4), Color("544e3c"))
		for x in [-1.12, 1.12]:
			world.box(body, Vector3(x, 1.65, 0.8), Vector3(0.16, 0.8, 2.7), color)
			for z in [-1.5, 1.5]:
				var wheel = world.cylinder(body, Vector3(x, 0.62, z), 0.6, 0.38, Color("242b29"))
				wheel.rotation_degrees.z = 90
		world.box(body, Vector3(0, 1.65, 2.1), Vector3(2.3, 0.8, 0.15), color)
	else:
		speed = 2.0 if kind == "zombie" else 4.2
		health = 48 if kind == "zombie" else 100
		world.box(body, Vector3(-0.21, 0.42, 0), Vector3(0.26, 0.84, 0.32), Color("353e3c")).name = "LegL"
		world.box(body, Vector3(0.21, 0.42, 0), Vector3(0.26, 0.84, 0.32), Color("353e3c")).name = "LegR"
		world.box(body, Vector3(0, 1.12, 0), Vector3(0.74, 0.72, 0.43), color)
		world.box(body, Vector3(0, 1.75, -0.02), Vector3(0.43, 0.45, 0.42), Color("809573") if kind == "zombie" else Color("c5a17e"))
		world.box(body, Vector3(-0.48, 1.05, -0.05), Vector3(0.2, 0.65, 0.22), color)
		world.box(body, Vector3(0.48, 1.05, -0.15), Vector3(0.2, 0.65, 0.22), color)
		if kind != "zombie":
			world.box(body, Vector3(0, 1.24, 0.34), Vector3(0.5, 0.64, 0.3), Color("746e4d"))
			world.box(body, Vector3(0, 2.0, 0), Vector3(0.5, 0.1, 0.46), color.darkened(0.25))
			world.box(body, Vector3(0.45, 1.07, -0.5), Vector3(0.12, 0.14, 0.86), Color("343b36"))
	ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.7 if kind == "truck" else 0.66
	torus.outer_radius = 1.86 if kind == "truck" else 0.8
	torus.rings = 20
	torus.ring_segments = 6
	ring.mesh = torus
	ring.material_override = world.material(Color("a9db9b"), true)
	add_child(ring)
	ring.position.y = 0.12
	ring.visible = false

func move_to(target: Vector3) -> bool:
	if not alive:
		return false
	var candidate: PackedVector3Array = world.route(position, target)
	if candidate.is_empty():
		return false
	path = candidate
	last_destination = target
	has_destination = true
	return true

func tick(delta: float) -> void:
	if not alive:
		return
	cooldown = maxf(0, cooldown - delta)
	repath -= delta
	ring.visible = selected
	if path.is_empty():
		has_destination = false
		return
	var target := path[0]
	var difference := target - position
	if difference.length() < maxf(0.15, speed * delta):
		position = target
		path.remove_at(0)
	else:
		position += difference.normalized() * speed * delta
		body.rotation.y = lerp_angle(body.rotation.y, atan2(-difference.x, -difference.z), minf(1, delta * 8))
		gait += delta * speed * 2.2
		if kind != "truck":
			body.get_node("LegL").rotation.x = sin(gait) * 0.45
			body.get_node("LegR").rotation.x = -sin(gait) * 0.45
			body.position.y = absf(sin(gait)) * 0.06

func damage(amount: float) -> void:
	if not alive:
		return
	health = maxf(0, health - amount)
	if health == 0:
		alive = false
		path.clear()
		selected = false
		ring.visible = false
		body.rotation.z = PI / 2
		body.position.y = 0.2
