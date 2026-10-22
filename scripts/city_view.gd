extends Node2D
signal person_selected(id: int)
signal building_selected(id: int)
signal ground_selected(cell: Vector2i)
const Catalog = preload("res://scripts/catalog.gd")
const Architecture = preload("res://scripts/architecture.gd")
const ResidentView = preload("res://scripts/resident_view.gd")
const Terrain = preload("res://scripts/terrain.gd")
var sim: CitySimulation
var camera: Camera2D
var terrain: Node2D
var objects: Node2D
var people: Array = []
var structures: Array = []
var vehicles: Array = []
var target_position = Vector2(0, 510)
var target_zoom: float = 0.72
var following: int = -1
var selected_person: int = -1
var selected_building: int = -1
var building_mode: bool = false
var dragging: bool = false
var drag_distance: float = 0.0
var touches: Dictionary = {}
var last_pinch: float = 0.0
var active: bool = false
var known_revision: int = -1
var is_night: bool = false
var low_detail: bool = false
var visual_time: float = 0.0

func _ready() -> void:
	terrain = Terrain.new()
	add_child(terrain)
	objects = Node2D.new()
	objects.y_sort_enabled = true
	add_child(objects)
	camera = Camera2D.new()
	camera.position = target_position
	camera.zoom = Vector2.ONE * target_zoom
	add_child(camera)

func bind(model: CitySimulation) -> void:
	sim = model
	terrain.sim = model
	for child in objects.get_children():
		child.free()
	people.clear()
	structures.clear()
	vehicles.clear()
	for r in sim.residents:
		var actor = ResidentView.new()
		actor.data = r
		actor.position = _person_position(r)
		objects.add_child(actor)
		people.append(actor)
	for i in 12:
		var car = Node2D.new()
		var index = i
		car.draw.connect(func(): _draw_car(car, index))
		objects.add_child(car)
		vehicles.append(car)
	known_revision = -1
	refresh()

func refresh() -> void:
	if sim == null:
		return
	if sim.revision != known_revision:
		for child in structures:
			child.free()
		structures.clear()
		for b in sim.buildings:
			var node = Architecture.new()
			node.data = b
			node.position = Catalog.iso(Vector2(b.x, b.y)) + Vector2(0, 40)
			node.night = is_night
			node.selected = b.id == selected_building
			objects.add_child(node)
			structures.append(node)
		terrain.building_mode = building_mode
		terrain.queue_redraw()
		known_revision = sim.revision

func _person_position(r: Dictionary) -> Vector2:
	# Small deterministic pavement offsets keep crowds legible without changing navigation.
	return Catalog.iso(Vector2(r.pos[0], r.pos[1])) + Vector2((r.id % 5 - 2) * 2.5, (r.id % 3 - 1) * 2.0 - 5)

func _process(delta: float) -> void:
	if sim == null:
		return
	visual_time += delta
	var night = sim.minute < 350 or sim.minute >= 1160
	if night != is_night:
		is_night = night
		for node in structures:
			node.night = night
			node.queue_redraw()
	var sun = clampf(sin((sim.minute - 360) / 1440.0 * TAU) * 1.7 + 0.45, 0.0, 1.0)
	modulate = Color("7284ad").lerp(Color.WHITE, sun)
	for i in people.size():
		var r: Dictionary = sim.residents[i]
		var actor = people[i]
		var next = _person_position(r)
		var movement = next - actor.position
		actor.position = actor.position.lerp(next, 1 - exp(-delta * 18))
		actor.walking = not r.path.is_empty()
		if absf(movement.x) > 0.05:
			actor.facing = signf(movement.x)
		actor.phase += delta * (10.5 if actor.walking else 1.0)
		actor.visible = actor.walking or r.activity in ["Отдыхает в сквере", "Идёт в сквер", "Покупает продукты", "Обедает"] or i == selected_person
		actor.selected = i == selected_person
		if actor.visible:
			actor.queue_redraw()
	for i in vehicles.size():
		var car = vehicles[i]
		car.visible = not low_detail or i < 5
		var distance = fmod(sim.day * 1440 + sim.minute + i * 47, 400) / 400.0 * 24.0
		var reverse = i % 2 == 0
		var p = Vector2((i % 6) * 4, 24 - distance if reverse else distance)
		if i >= 6:
			p = Vector2(distance if reverse else 24 - distance, (i % 6) * 4)
		car.position = car.position.lerp(Catalog.iso(p) + Vector2(7, 0), 1 - exp(-delta * 12)) if visual_time > 0.1 else Catalog.iso(p)
		car.queue_redraw()
	if following >= 0 and following < people.size():
		target_position = people[following].position + Vector2(0, -30)
	target_position.x = clampf(target_position.x, -1000, 1000)
	target_position.y = clampf(target_position.y, -50, 1150)
	camera.position = camera.position.lerp(target_position, 1 - exp(-delta * 9))
	camera.zoom = camera.zoom.lerp(Vector2.ONE * target_zoom, 1 - exp(-delta * 11))
	refresh()

func _draw_car(car: Node2D, index: int) -> void:
	var color = Color(["d88f72", "e4d1a0", "8eb8b1", "97a8c3", "c2a1b3", "e2c97c"][index % 6])
	var dir = 1 if index < 6 else -1
	var points = PackedVector2Array([Vector2(-12, -2 * dir), Vector2(2, -9), Vector2(14, -3 * dir), Vector2(0, 5)])
	car.draw_colored_polygon(points, color.darkened(0.1))
	car.draw_colored_polygon(PackedVector2Array([Vector2(-8, -5), Vector2(1, -10), Vector2(9, -6), Vector2(0, -1)]), color.lightened(0.12))
	car.draw_line(Vector2(-7, -6), Vector2(0, -2), Color("58777e"), 3, true)
	car.draw_circle(Vector2(-7, 1), 2.5, Color("3d5056"))
	car.draw_circle(Vector2(8, 0), 2.5, Color("3d5056"))
	if is_night:
		car.draw_circle(Vector2(12, -2), 3, Color(1, 0.88, 0.63, 0.7))

func set_build_mode(value: bool) -> void:
	building_mode = value
	terrain.building_mode = value
	terrain.queue_redraw()

func select_building(id: int) -> void:
	selected_building = id
	for node in structures:
		node.selected = node.data.id == id
		node.queue_redraw()

func focus_person(id: int, follow: bool = false) -> void:
	selected_person = id
	following = id if follow else -1
	target_position = people[id].position
	target_zoom = maxf(1.3, target_zoom)

func zoom_by(factor: float) -> void:
	target_zoom = clampf(target_zoom * factor, 0.4, 2.25)

func _input(event: InputEvent) -> void:
	# A gesture may finish over a UI panel, which consumes the unhandled event.
	# Deferred cleanup lets normal map taps finish first and prevents stuck drags.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		call_deferred("_release_mouse")
	elif event is InputEventScreenTouch and not event.pressed:
		call_deferred("_release_touch", event.index)

func _release_mouse() -> void:
	dragging = false

func _release_touch(index: int) -> void:
	touches.erase(index)
	last_pinch = 0

func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			zoom_by(1.12)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom_by(1.0 / 1.12)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				dragging = true
				drag_distance = 0
			else:
				if dragging and drag_distance < 10:
					_pick(event.position)
				dragging = false
	elif event is InputEventMouseMotion and dragging:
		target_position -= event.relative / camera.zoom.x
		drag_distance += event.relative.length()
		following = -1
	elif event is InputEventScreenTouch:
		if event.pressed:
			touches[event.index] = event.position
			if touches.size() == 1:
				drag_distance = 0
			else:
				drag_distance = 100
		else:
			if touches.size() == 1 and drag_distance < 12:
				_pick(event.position)
			touches.erase(event.index)
			last_pinch = 0
	elif event is InputEventScreenDrag:
		if not touches.has(event.index):
			return
		touches[event.index] = event.position
		following = -1
		if touches.size() == 1:
			target_position -= event.relative / camera.zoom.x
			drag_distance += event.relative.length()
		elif touches.size() >= 2:
			var points = touches.values()
			var distance: float = points[0].distance_to(points[1])
			if last_pinch > 0:
				zoom_by(distance / last_pinch)
			last_pinch = distance
	elif event is InputEventMagnifyGesture:
		zoom_by(event.factor)

func _pick(screen: Vector2) -> void:
	var world = get_canvas_transform().affine_inverse() * screen
	var cell = Catalog.uniso(world)
	if building_mode:
		ground_selected.emit(Vector2i(roundi(cell.x), roundi(cell.y)))
		return
	var closest = -1
	var distance = 25.0 / camera.zoom.x
	for i in people.size():
		if not people[i].visible:
			continue
		var d: float = (people[i].position + Vector2(0, -10)).distance_to(world)
		if d < distance:
			distance = d
			closest = i
	if closest >= 0:
		person_selected.emit(closest)
		return
	# Picking the roof or facade counts as picking that building.
	for i in range(structures.size() - 1, -1, -1):
		var node = structures[i]
		var local = world - node.position
		var height = 230 if node.data.type == "tower" else 205
		if absf(local.x) < 74 and local.y < 0 and local.y > -height:
			building_selected.emit(node.data.id)
			return
	ground_selected.emit(Vector2i(roundi(cell.x), roundi(cell.y)))
