extends Control

var game: Node3D

func _ready() -> void:
	custom_minimum_size = Vector2(222, 180)
	mouse_filter = Control.MOUSE_FILTER_STOP

func map_point(p: Vector3) -> Vector2:
	return Vector2((p.x + 80) / 160 * size.x, (p.z + 80) / 160 * size.y)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("293b32"))
	draw_line(map_point(Vector3(-80, 0, 8)), map_point(Vector3(80, 0, 8)), Color("797c64"), 4)
	draw_line(map_point(Vector3(15, 0, 8)), map_point(Vector3(15, 0, -45)), Color("797c64"), 3)
	draw_line(Vector2(size.x / 2, 0), Vector2(size.x / 2, size.y), Color("526453"), 1)
	if not is_instance_valid(game) or not is_instance_valid(game.world):
		return
	draw_circle(map_point(game.world.depot), 6, Color("d7e6ad"))
	for site in game.world.sites:
		draw_circle(map_point(site.position), 4, Color("d3a561"))
	for unit in game.squad:
		if unit.alive:
			draw_circle(map_point(unit.position), 3, Color("c9f5b8"))
	if game.truck.alive:
		draw_rect(Rect2(map_point(game.truck.position) - Vector2(3, 3), Vector2(6, 6)), Color("c9d5e3"))
	for enemy in game.zombies:
		if enemy.alive:
			draw_circle(map_point(enemy.position), 2, Color("c77658"))
	var center := map_point(game.focus)
	draw_rect(Rect2(center - Vector2(22, 16), Vector2(44, 32)), Color("e0e5bf"), false, 1.5)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		game.focus = Vector3(event.position.x / size.x * 160 - 80, 0, event.position.y / size.y * 160 - 80)
		accept_event()
