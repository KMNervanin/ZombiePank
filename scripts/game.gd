extends Node3D

const World = preload("res://scripts/world.gd")
const Unit = preload("res://scripts/unit.gd")
const Minimap = preload("res://scripts/minimap.gd")
var world: Node3D
var camera: Camera3D
var focus := Vector3(-21, 0, 2)
var zoom := 48.0
var yaw := 0.4
var residents: Array = []
var squad: Array = []
var zombies: Array = []
var truck: Node3D
var selection := ""
var aboard := false
var population := 8
var materials := 24
var cargo := 0
var truck_cargo := 0
var delivered := 0
var muster_built := false
var expansion_built := false
var construction := 0.0
var gathering := -1
var gather_progress := 0.0
var elapsed := 0.0
var simulation_speed := 1.0
var paused := false
var idle_clock := 0.0
var notice_time := 0.0
var flash_lines: Array = []
var stats: Label
var objective: Label
var selected_info: Label
var notice: Label
var status_line: Label
var build_button: Button
var squad_button: Button
var truck_button: Button
var board_button: Button
var gather_button: Button
var expand_button: Button
var map: Control
var marker: Node3D
var help_panel: PanelContainer
var test_mode := false
var test_failures := 0

func _ready() -> void:
	test_mode = "--smoke-test" in OS.get_cmdline_user_args() or "--ui-test" in OS.get_cmdline_user_args()
	world = World.new()
	add_child(world)
	camera = Camera3D.new()
	add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.far = 500
	camera.current = true
	for i in range(8):
		var person = spawn_unit("resident", Vector3(-32 + (i % 4) * 2, 0, 4 + floori(i / 4.0) * 3), Color("688c83") if i % 2 else Color("a08b67"))
		residents.append(person)
	truck = spawn_unit("truck", Vector3(-24, 0, 14), Color("768879"))
	for p in [Vector3(24, 0, 5), Vector3(28, 0, 9), Vector3(37, 0, 12), Vector3(43, 0, 4), Vector3(18, 0, -30), Vector3(9, 0, -35)]:
		zombies.append(spawn_unit("zombie", p, Color("64765a")))
	marker = Node3D.new()
	add_child(marker)
	for i in range(4):
		var angle := i * PI / 2
		world.box(marker, Vector3(cos(angle) * 0.9, 0.12, sin(angle) * 0.9), Vector3(0.3, 0.1, 0.3), Color("e6c281"))
	marker.visible = false
	create_ui()
	update_camera()
	update_ui()
	if "--ui-test" in OS.get_cmdline_user_args():
		call_deferred("ui_test")
	elif test_mode:
		call_deferred("smoke_test")
	elif "--capture" in OS.get_cmdline_user_args():
		call_deferred("capture_preview")

func spawn_unit(kind: String, at: Vector3, color: Color) -> Node3D:
	var unit = Unit.new()
	add_child(unit)
	unit.setup(world, kind, at, color)
	return unit

func panel(parent: Node, position_: Vector2, size_: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	parent.add_child(p)
	p.position = position_
	p.custom_minimum_size = size_
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.075, 0.105, 0.09, 0.95)
	style.border_color = Color("465343")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 15
	style.content_margin_bottom = 15
	p.add_theme_stylebox_override("panel", style)
	return p

func label(parent: Node, text: String, font_size: int = 18, tint := Color("d8dfcc")) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", tint)
	parent.add_child(l)
	return l

func button(parent: Node, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 40)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(action)
	parent.add_child(b)
	return b

func create_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	layer.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	theme.default_font_size = 17
	for state in ["normal", "hover", "pressed", "disabled"]:
		var s := StyleBoxFlat.new()
		s.bg_color = Color("35473a") if state == "normal" else Color("52674b")
		if state == "disabled":
			s.bg_color = Color("222d27")
		s.set_corner_radius_all(4)
		s.content_margin_left = 13
		s.content_margin_right = 13
		theme.set_stylebox(state, "Button", s)
	theme.set_color("font_color", "Button", Color("e1e6d2"))
	theme.set_color("font_disabled_color", "Button", Color("778477"))
	root.theme = theme
	var top := panel(root, Vector2(22, 20), Vector2(1556, 72))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 30)
	top.add_child(row)
	label(row, "ZOMBIEPANK", 28, Color("dce6b9"))
	label(row, "ПЕРВОЕ УБЕЖИЩЕ   /   3D-ПРОТОТИП", 15, Color("929f88"))
	stats = label(row, "", 18)
	stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button(row, "Ⅱ / ▶  Пробел", toggle_pause)
	button(row, "×1 / ×3", func(): simulation_speed = 3.0 if simulation_speed == 1 else 1.0)
	button(row, "?", func(): help_panel.visible = not help_panel.visible)
	var left := panel(root, Vector2(22, 112), Vector2(318, 0))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 11)
	left.add_child(column)
	label(column, "01  /  ЗАКРЕПИТЬСЯ", 16, Color("d3b681"))
	objective = label(column, "", 18)
	objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective.custom_minimum_size = Vector2(276, 152)
	label(column, "ОБЩИНА", 14, Color("91a48b"))
	build_button = button(column, "Построить сборный пункт · 12", build_muster)
	squad_button = button(column, "Собрать отряд · 3 жителя  [1]", muster_squad)
	expand_button = button(column, "Расширить базу · 24 материала", expand_base)
	button(column, "Вернуться к базе  [H]", func(): focus = Vector3(-28, 0, 2))
	var bottom := panel(root, Vector2(362, 816), Vector2(1216, 162))
	var bc := VBoxContainer.new()
	bc.add_theme_constant_override("separation", 9)
	bottom.add_child(bc)
	selected_info = label(bc, "", 20)
	status_line = label(bc, "", 16, Color("a8b79e"))
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	bc.add_child(actions)
	truck_button = button(actions, "Грузовик  [2]", select_truck)
	board_button = button(actions, "Посадка / высадка  [F]", toggle_board)
	gather_button = button(actions, "Забрать ресурсы / людей  [E]", gather)
	button(actions, "Вернуться с грузом  [R]", return_home)
	button(actions, "Распустить отряд", disband)
	var minimap_panel := panel(root, Vector2(22, 713), Vector2(318, 265))
	var mc := VBoxContainer.new()
	minimap_panel.add_child(mc)
	label(mc, "ОКРЕСТНОСТИ  /  нажми для перехода", 13, Color("b2bfa4"))
	map = Minimap.new()
	map.game = self
	mc.add_child(map)
	label(mc, "● община     ● объекты     ● угроза", 13, Color("abb99e"))
	var notice_panel := panel(root, Vector2(362, 112), Vector2(920, 55))
	notice = label(notice_panel, "Начни со сборного пункта. Камера: WASD, колесо, Q / Alt+E.", 17, Color("ece4c5"))
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice.custom_minimum_size.x = 880
	notice.add_theme_color_override("font_shadow_color", Color.BLACK)
	notice.add_theme_constant_override("shadow_offset_x", 2)
	notice.add_theme_constant_override("shadow_offset_y", 2)
	notice_time = 18
	help_panel = panel(root, Vector2(455, 210), Vector2(710, 0))
	var hc := VBoxContainer.new()
	hc.add_theme_constant_override("separation", 13)
	help_panel.add_child(hc)
	label(hc, "ТВОЯ ПЕРВАЯ ВЫЛАЗКА", 27, Color("dfd9b1"))
	label(hc, "Один дом. Восемь человек. За воротами — неизвестность.", 19)
	label(hc, "1. Построй сборный пункт и собери отряд.\n2. Выбери отряд клавишей 1. ПКМ — приказ идти.\n3. Подойди к складу и нажми E, чтобы забрать материалы.\n4. Нажми R: отряд вернётся и разгрузится на базе.\n5. Построй дополнительное жильё.", 19)
	label(hc, "WASD / стрелки — камера · Колесо — масштаб · Q / Alt+E — поворот\nСКМ + движение мыши — перемещение камеры\nЛКМ — выбрать отряд или машину · 2 — грузовик\nF — посадка рядом с машиной / высадка · Пробел — пауза\nH — камера к базе · Esc — закрыть справку · F5 — начать заново", 17, Color("a9b9a1"))
	label(hc, "Бой автоматический. В машине отряд не стреляет.\nПешком можно унести 24 материала, на грузовике — 80.\nПри гибели отряда можно собрать новый из оставшихся жителей.", 17, Color("d4b28b"))
	button(hc, "Начать  →", func(): help_panel.hide())
	help_panel.visible = not test_mode and not "--capture" in OS.get_cmdline_user_args()

func toast(text: String) -> void:
	notice.text = text
	notice_time = 7

func toggle_pause() -> void:
	paused = not paused

func build_muster() -> void:
	if muster_built or construction > 0:
		return
	if materials < 12:
		toast("Для сборного пункта нужны 12 материалов.")
		return
	materials -= 12
	construction = 5
	toast("Жители строят сборный пункт у ворот…")

func muster_squad() -> void:
	if not muster_built:
		toast("Сначала построй сборный пункт у ворот.")
		return
	if not squad.is_empty():
		selection = "squad"
		focus = squad_center()
		return
	if residents.size() < 3:
		toast("Для отряда нужны 3 свободных жителя. F5 — новая попытка.")
		return
	for i in range(3):
		var person = residents.pop_back()
		squad.append(person)
		person.move_to(Vector3(-18 + i * 2, 0, 8))
	selection = "squad"
	toast("Трое жителей в отряде. ПКМ — идти, E — забрать добычу рядом с объектом.")

func expand_base() -> void:
	if expansion_built:
		return
	if materials < 24:
		toast("Нужны 24 материала. Привези их со склада или лесопилки.")
		return
	materials -= 24
	expansion_built = true
	world.tent(Vector3(-37, 0, 19))
	world.tent(Vector3(-45, 0, 19))
	toast("Новые палатки готовы. Первая вылазка стала началом растущей общины.")

func select_truck() -> void:
	if not truck.alive:
		toast("Грузовик уничтожен.")
		return
	selection = "truck"
	focus = truck.position
	if not aboard:
		toast("Машине нужен водитель. Подведи отряд и нажми F.")

func squad_center() -> Vector3:
	if aboard:
		return truck.position
	if squad.is_empty():
		return world.depot
	var center := Vector3.ZERO
	for person in squad:
		center += person.position
	return center / squad.size()

func active_position() -> Vector3:
	return truck.position if selection == "truck" or aboard else squad_center()

func toggle_board() -> void:
	if squad.is_empty() or not truck.alive:
		toast("Нужны собранный отряд и исправный грузовик.")
		return
	if aboard:
		var spots: Array[Vector3] = []
		for offset in [Vector3(-4, 0, 0), Vector3(4, 0, 0), Vector3(0, 0, 4), Vector3(0, 0, -4), Vector3(-4, 0, 4), Vector3(4, 0, 4)]:
			var p: Vector3 = truck.position + offset
			if not world.navigation.is_point_solid(world.to_cell(p)):
				spots.append(p)
		if spots.size() < squad.size():
			toast("Мало места для высадки. Отъедь на открытый участок.")
			return
		aboard = false
		truck.path.clear()
		for i in range(squad.size()):
			squad[i].position = spots[i]
			squad[i].show()
		selection = "squad"
		toast("Отряд высадился. Груз остаётся в кузове до разгрузки на базе.")
	else:
		if truck_cargo + cargo > 80:
			toast("В кузове нет места для груза отряда. Сначала разгрузи машину на базе.")
			return
		for person in squad:
			if person.position.distance_to(truck.position) > 9:
				toast("Подведи весь отряд ближе к грузовику: не дальше 9 метров.")
				return
		aboard = true
		for person in squad:
			person.path.clear()
			person.hide()
		truck_cargo += cargo
		cargo = 0
		selection = "truck"
		toast("Отряд в машине. ПКМ — ехать. F — высадиться перед боем.")
	gathering = -1

func command_move(target: Vector3) -> void:
	gathering = -1
	var moved := false
	if selection == "truck" or aboard:
		if not aboard:
			toast("Сначала посади отряд в машину клавишей F.")
			return
		moved = truck.move_to(target)
	elif selection == "squad":
		for i in range(squad.size()):
			var offset := Vector3((i - 1) * 2, 0, (i % 2) * 2)
			moved = squad[i].move_to(world.nearest_free(target + offset)) or moved
	else:
		toast("Собери и выбери отряд [1] или выбери грузовик [2].")
		return
	if moved:
		marker.position = target
		marker.visible = true
	else:
		toast("Здесь препятствие или нет прохода. Укажи свободную землю рядом.")

func return_home() -> void:
	command_move(world.depot)

func disband() -> void:
	if aboard or squad_center().distance_to(world.depot) > 9:
		toast("Верни отряд на базу и высади из машины.")
		return
	for person in squad:
		person.selected = false
		residents.append(person)
	squad.clear()
	selection = ""
	gathering = -1
	toast("Люди вернулись к работе в общине.")

func gather() -> void:
	if squad.is_empty():
		toast("Сначала собери отряд.")
		return
	var p := active_position()
	if selection == "truck" and not aboard:
		toast("Пустая машина не может собирать ресурсы. Выбери отряд [1].")
		return
	for i in range(world.sites.size()):
		var site: Dictionary = world.sites[i]
		if p.distance_to(site.position) < 8:
			if site.stock <= 0:
				toast("Здесь больше ничего не осталось.")
				return
			if danger_near(p):
				toast("Сначала зачисти окрестности. Выйди из машины для боя.")
				return
			if site.kind == "materials" and (truck_cargo >= 80 if aboard else cargo >= squad.size() * 8):
				toast("Груз заполнен. Вернись на базу для разгрузки [R].")
				return
			gathering = i
			gather_progress = 0
			for person in squad:
				person.path.clear()
			truck.path.clear()
			toast("Погрузка…" if site.kind == "materials" else "Разговариваем с выжившими…")
			return
	toast("Подойди к золотому маркеру склада, лесопилки или лагеря и нажми E.")

func danger_near(at: Vector3) -> bool:
	for enemy in zombies:
		if enemy.alive and enemy.position.distance_to(at) < 11:
			return true
	return false

func update_gather(delta: float) -> void:
	if gathering < 0:
		return
	var site: Dictionary = world.sites[gathering]
	if squad.is_empty() or active_position().distance_to(site.position) >= 8 or danger_near(active_position()):
		gathering = -1
		toast("Сбор прерван: отряд ушёл или рядом появилась угроза.")
		return
	gather_progress += delta
	if gather_progress < 4:
		return
	if site.kind == "materials":
		var space := 80 - truck_cargo if aboard else squad.size() * 8 - cargo
		var amount := mini(space, site.stock)
		site.stock -= amount
		if aboard:
			truck_cargo += amount
		else:
			cargo += amount
		toast("Забрали %d материалов. Верни груз на базу [R]." % amount)
	else:
		var count: int = site.stock
		site.stock = 0
		population += count
		for i in range(count):
			var person = spawn_unit("resident", world.nearest_free(site.position + Vector3(i * 2, 0, 2)), Color("b99c73"))
			residents.append(person)
			person.move_to(world.depot + Vector3(i * 2, 0, -3))
		toast("%d выживших согласились присоединиться и идут к убежищу." % count)
	gathering = -1

func fire(from: Vector3, to: Vector3) -> void:
	var length := from.distance_to(to)
	if length < 0.01:
		return
	var beam = world.box(self, (from + to) / 2 + Vector3(0, 1.2, 0), Vector3(0.055, 0.055, length), Color("f2c887"))
	beam.look_at(to + Vector3(0, 1.2, 0), Vector3.UP)
	flash_lines.append({"node": beam, "life": 0.09})

func update_combat(delta: float) -> void:
	var targets: Array = residents.duplicate()
	if aboard:
		targets.append(truck)
	else:
		targets.append_array(squad)
	for enemy in zombies:
		if not enemy.alive:
			continue
		var victim: Node3D = null
		var nearest := 17.0
		for person in targets:
			if person.alive:
				var d: float = enemy.position.distance_to(person.position)
				if d < nearest:
					nearest = d
					victim = person
		if victim != null:
			if nearest < (3.0 if victim == truck else 1.8):
				enemy.path.clear()
				if enemy.cooldown <= 0:
					victim.damage(13)
					enemy.cooldown = 1.1
			elif enemy.repath <= 0:
				enemy.move_to(victim.position)
				enemy.repath = 0.8
	if not aboard:
		for person in squad:
			if not person.alive or person.cooldown > 0:
				continue
			var victim: Node3D = null
			var nearest := 13.0
			for enemy in zombies:
				var d: float = person.position.distance_to(enemy.position)
				if enemy.alive and d < nearest and clear_shot(person.position, enemy.position):
					victim = enemy
					nearest = d
			if victim != null:
				fire(person.position, victim.position)
				victim.damage(18)
				person.cooldown = 0.85
	if aboard and not truck.alive:
		aboard = false
		truck_cargo = 0
		for person in squad:
			person.position = truck.position
			person.show()
			person.damage(100)
		toast("Грузовик уничтожен. Отряд и груз потеряны. Можно собрать новый отряд.")
	for group in [squad, residents]:
		for i in range(group.size() - 1, -1, -1):
			if not group[i].alive:
				group.remove_at(i)
				population -= 1
				if group == squad:
					cargo = mini(cargo, squad.size() * 8)
	if squad.is_empty():
		cargo = 0
		gathering = -1

func clear_shot(from: Vector3, to: Vector3) -> bool:
	var distance := from.distance_to(to)
	for i in range(1, ceili(distance)):
		var p := from.lerp(to, float(i) / distance)
		if world.navigation.is_point_solid(world.to_cell(p)):
			return false
	return true

func update_camera() -> void:
	focus.x = clampf(focus.x, -65, 65)
	focus.z = clampf(focus.z, -65, 65)
	var offset := Vector3(0, 65, 55).rotated(Vector3.UP, yaw)
	camera.position = focus + offset
	camera.look_at(focus, Vector3.UP)
	camera.size = zoom

func ground_point(screen: Vector2) -> Variant:
	return Plane(Vector3.UP, 0).intersects_ray(camera.project_ray_origin(screen), camera.project_ray_normal(screen))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom = maxf(23, zoom - 4)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom = minf(120, zoom + 4)
		elif event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			var p = ground_point(event.position)
			if p == null:
				return
			if event.button_index == MOUSE_BUTTON_RIGHT:
				command_move(p)
			elif truck.alive and p.distance_to(truck.position) < 3.5:
				selection = "truck"
			else:
				for person in squad:
					if p.distance_to(person.position) < 3:
						selection = "squad"
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		focus += Vector3(-event.relative.x, 0, -event.relative.y).rotated(Vector3.UP, yaw) * zoom / 750
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: muster_squad()
			KEY_2: select_truck()
			KEY_F: toggle_board()
			KEY_E:
				if not event.alt_pressed:
					gather()
			KEY_R: return_home()
			KEY_H: focus = Vector3(-28, 0, 2)
			KEY_SPACE: toggle_pause()
			KEY_ESCAPE: help_panel.visible = not help_panel.visible
			KEY_F5: get_tree().reload_current_scene()

func _process(delta: float) -> void:
	var direction := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): direction.z -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): direction.z += 1
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): direction.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): direction.x += 1
	if Input.is_physical_key_pressed(KEY_Q): yaw -= delta * 0.9
	if Input.is_physical_key_pressed(KEY_E) and Input.is_key_pressed(KEY_ALT): yaw += delta * 0.9
	focus += direction.rotated(Vector3.UP, yaw) * delta * zoom * 0.65
	update_camera()
	if not test_mode and not paused and not help_panel.visible:
		simulate(minf(delta, 0.1) * simulation_speed)
	notice_time -= delta
	notice.get_parent().visible = notice_time > 0
	update_ui()
	map.queue_redraw()

func simulate(delta: float) -> void:
	elapsed += delta
	if construction > 0:
		construction -= delta
		if construction <= 0:
			muster_built = true
			world.finish_muster()
			toast("Сборный пункт готов. Теперь можно собрать отряд [1].")
	for person in residents:
		person.tick(delta)
	for person in squad:
		person.selected = selection == "squad" and not aboard
		if aboard:
			person.position = truck.position
		else:
			person.tick(delta)
	truck.selected = selection == "truck"
	truck.tick(delta)
	for enemy in zombies:
		enemy.tick(delta)
	update_combat(delta)
	update_gather(delta)
	if cargo > 0 and squad_center().distance_to(world.depot) < 5:
		materials += cargo
		delivered += cargo
		toast("На склад общины доставлено %d материалов." % cargo)
		cargo = 0
	if truck_cargo > 0 and truck.position.distance_to(world.depot) < 5 and truck.alive:
		materials += truck_cargo
		delivered += truck_cargo
		toast("Грузовик разгружен: +%d материалов." % truck_cargo)
		truck_cargo = 0
	idle_clock += delta
	if idle_clock > 7:
		idle_clock = 0
		var work_spots := [Vector3(-28, 0, 4), Vector3(-40, 0, -12), Vector3(-31, 0, -1), Vector3(-37, 0, 7)]
		for i in range(residents.size()):
			if residents[i].path.is_empty():
				residents[i].move_to(work_spots[(i + floori(elapsed / 7)) % work_spots.size()])
	for i in range(flash_lines.size() - 1, -1, -1):
		flash_lines[i].life -= delta
		if flash_lines[i].life <= 0:
			flash_lines[i].node.queue_free()
			flash_lines.remove_at(i)

func update_ui() -> void:
	stats.text = "Жители  %d    ·    В общине  %d    ·    Материалы  %d    |    %s" % [population, residents.size(), materials, "ПАУЗА" if paused else "×%d" % simulation_speed]
	if not muster_built:
		objective.text = "Дом уже наш. Обустрой сборный пункт у ворот, чтобы отправить людей на вылазку."
	elif squad.is_empty() and delivered == 0:
		objective.text = "Собери отряд из трёх жителей. Их отсутствие уменьшит число работников в общине."
	elif delivered < 24:
		objective.text = "Привези 24 материала со склада на востоке.\nДоставлено: %d / 24\nЗомби атакуют приблизившихся людей." % delivered
	elif not expansion_built:
		objective.text = "Ресурсы дома. Расширь базу: поставь две жилые палатки."
	else:
		objective.text = "ПЕРВЫЙ ШАГ СДЕЛАН\nПродолжай исследовать карту: лесопилка на севере, выжившие на юге."
	build_button.disabled = muster_built or construction > 0 or materials < 12
	build_button.text = "Сборный пункт готов" if muster_built else ("Строительство… %d с" % ceili(construction) if construction > 0 else "Построить сборный пункт · 12")
	squad_button.disabled = not muster_built or (residents.size() < 3 and squad.is_empty())
	squad_button.text = "Выбрать отряд  [1]" if not squad.is_empty() else "Собрать отряд · 3 жителя  [1]"
	expand_button.disabled = materials < 24 or expansion_built or not muster_built
	expand_button.text = "База расширена" if expansion_built else "Расширить базу · 24 материала"
	board_button.disabled = squad.is_empty() or not truck.alive
	gather_button.disabled = squad.is_empty()
	truck_button.disabled = not truck.alive
	if aboard or selection == "truck":
		selected_info.text = "ГРУЗОВИК   /   %s   /   прочность %d%%   /   груз %d / 80" % ["отряд внутри" if aboard else "без водителя", truck.health / 2.4, truck_cargo]
	elif selection == "squad" and not squad.is_empty():
		var health_text := ""
		for person in squad:
			health_text += "%d%%  " % person.health
		selected_info.text = "ОТРЯД   /   %d чел.   /   здоровье %s   /   груз %d / %d" % [squad.size(), health_text, cargo, squad.size() * 8]
	else:
		selected_info.text = "ОБЩИНА   /   выбери отряд или грузовик"
	status_line.text = "ПКМ — идти   ·   WASD — камера   ·   Колесо — масштаб   ·   Q / Alt+E — поворот   ·   ? — справка"
	if gathering >= 0:
		status_line.text = "ПОГРУЗКА   %d%%   ·   %s" % [int(gather_progress / 4 * 100), world.sites[gathering].name]

func capture_preview() -> void:
	await get_tree().create_timer(2).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://preview.png")
	print("PREVIEW: ", ProjectSettings.globalize_path("user://preview.png"))
	get_tree().quit()

func check(condition: bool, message: String) -> void:
	if not condition:
		test_failures += 1
		push_error("SMOKE FAIL: " + message)
	else:
		print("PASS: ", message)

func advance(seconds: float) -> void:
	for i in range(ceili(seconds * 30)):
		simulate(1.0 / 30.0)

func smoke_test() -> void:
	check(population == 8 and residents.size() == 8, "eight residents at start")
	build_muster()
	advance(6)
	check(muster_built and materials == 12, "construction spends resources and finishes")
	muster_squad()
	advance(10)
	check(squad.size() == 3 and residents.size() == 5, "squad uses existing workers")
	command_move(Vector3(22, 0, 8))
	advance(28)
	command_move(world.sites[0].position)
	advance(20)
	check(not squad.is_empty(), "squad survives a warehouse sortie")
	check(squad_center().distance_to(world.sites[0].position) < 8, "squad path reaches warehouse")
	gather()
	advance(5)
	check(cargo > 0 and world.sites[0].stock < 120, "warehouse supplies actually collected")
	return_home()
	advance(35)
	check(delivered >= 24 and cargo == 0 and materials >= 36, "cargo delivered to home stockpile")
	expand_base()
	check(expansion_built and materials == 12, "delivered supplies build settlement extension")
	command_move(truck.position)
	advance(12)
	toggle_board()
	check(aboard, "squad boards parked truck")
	command_move(world.sites[0].position)
	advance(20)
	gather()
	advance(5)
	check(truck_cargo == 80, "truck carries 80 materials")
	return_home()
	advance(20)
	check(truck_cargo == 0 and delivered == 104, "truck unloads at base")
	toggle_board()
	check(not aboard and squad[0].visible, "squad disembarks on free ground")
	selection = "squad"
	command_move(world.sites[2].position)
	advance(30)
	gather()
	advance(5)
	check(population == 12 and residents.size() == 9, "survivors join community")
	advance(40)
	var rescue_arrived := 0
	for person in residents:
		if person.position.distance_to(world.depot) < 18:
			rescue_arrived += 1
	check(rescue_arrived >= 4, "rescued residents walk home")
	check(world.route(Vector3(-24, 0, 8), Vector3(-35, 0, -7)).is_empty(), "orders into buildings are rejected")
	var pop_before := population
	var victim = squad[0]
	victim.damage(100)
	advance(0.1)
	check(population == pop_before - 1 and squad.size() == 2 and not victim.alive, "death removes a real resident from the community")
	selection = "squad"
	return_home()
	advance(40)
	disband()
	check(squad.is_empty() and residents.size() == population, "survivors of a sortie return to the workforce")
	print("SMOKE TEST COMPLETE")
	get_tree().quit(0 if test_failures == 0 else 1)

func input_click(point: Vector2, mouse_button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	point = get_viewport().get_screen_transform() * point
	var motion := InputEventMouseMotion.new()
	motion.position = point
	Input.parse_input_event(motion)
	await get_tree().process_frame
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = mouse_button
		event.pressed = pressed
		Input.parse_input_event(event)
		await get_tree().process_frame

func input_key(key: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.physical_keycode = key
		event.pressed = pressed
		Input.parse_input_event(event)
		await get_tree().process_frame

func ui_test() -> void:
	await get_tree().create_timer(0.5).timeout
	await input_click(build_button.get_global_rect().get_center())
	check(construction > 0, "mouse click on build button")
	advance(6)
	await input_key(KEY_1)
	advance(10)
	check(squad.size() == 3 and selection == "squad", "keyboard selects assembled squad")
	if squad.is_empty():
		get_tree().quit(1)
		return
	focus = Vector3(5, 0, 6)
	zoom = 70
	update_camera()
	await get_tree().process_frame
	await input_click(camera.unproject_position(Vector3(22, 0, 8)), MOUSE_BUTTON_RIGHT)
	check(not squad[0].path.is_empty(), "right click on terrain issues movement order")
	advance(28)
	await input_click(camera.unproject_position(world.sites[0].position), MOUSE_BUTTON_RIGHT)
	advance(20)
	await input_key(KEY_E)
	advance(5)
	check(cargo > 0, "E key collects resources after combat")
	await input_key(KEY_SPACE)
	check(paused, "space pauses after interacting with UI buttons")
	await input_key(KEY_SPACE)
	check(not paused, "space resumes")
	await input_key(KEY_R)
	advance(35)
	check(delivered >= 24, "R key returns squad and unloads cargo")
	update_ui()
	await get_tree().process_frame
	await get_tree().process_frame
	await input_click(expand_button.get_global_rect().get_center())
	check(expansion_built, "mouse builds expansion with delivered materials")
	await input_click(map.get_global_rect().position + map.size * Vector2(0.6, 0.3))
	check(focus.x > 0 and focus.z < 0, "minimap click moves camera")
	focus = Vector3(-22, 0, 3)
	zoom = 48
	update_camera()
	update_ui()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://ui-test.png")
	print("UI TEST COMPLETE: ", test_failures, " failures; renderer: ", RenderingServer.get_video_adapter_name())
	get_tree().quit(0 if test_failures == 0 else 1)
