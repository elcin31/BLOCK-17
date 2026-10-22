extends Node2D
const Catalog = preload("res://scripts/catalog.gd")
const Simulation = preload("res://scripts/simulation.gd")
const CityView = preload("res://scripts/city_view.gd")
const Store = preload("res://scripts/save_store.gd")
const INK = Color("142e3d")
const CREAM = Color("f5eedc")
const MUTED = Color("a9bfc0")
const GOLD = Color("efca88")
const MINT = Color("9bc8ac")
var sim: CitySimulation
var city: Node2D
var ui: Control
var hud: Control
var menu: Control
var side: PanelContainer
var panel_content: VBoxContainer
var panel_kind: String = ""
var toast_label: Label
var toast_time: float = 0
var clock_label: Label
var budget_label: Label
var population_label: Label
var mood_label: Label
var news_label: Label
var speed_buttons: Dictionary = {}
var speed: int = 1
var previous_speed: int = 1
var running: bool = false
var accumulator: float = 0
var refresh_time: float = 0
var autosave_time: float = 0
var selected_type: String = ""
var selected_resident: int = -1
var person_labels: Dictionary = {}
var person_version: String = ""
var settings = {"ambience": true, "low_detail": false}
var audio: AudioStreamPlayer
var screen_blocker: ColorRect

func _ready() -> void:
	_load_settings()
	sim = Simulation.new()
	sim.new_city()
	city = CityView.new()
	add_child(city)
	city.bind(sim)
	city.low_detail = settings.low_detail
	city.person_selected.connect(_show_person)
	city.building_selected.connect(_show_building)
	city.ground_selected.connect(_on_ground)
	_create_theme()
	get_viewport().size_changed.connect(_apply_safe_area)
	call_deferred("_apply_safe_area")
	_create_hud()
	_create_side()
	_create_toast()
	_create_audio()
	_show_menu()
	get_tree().auto_accept_quit = false

func _create_theme() -> void:
	var layer = CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	var theme = Theme.new()
	theme.default_font = preload("res://assets/DejaVuSans.ttf")
	theme.default_font_size = 15
	theme.set_color("font_color", "Label", CREAM)
	theme.set_color("font_color", "Button", CREAM)
	theme.set_color("font_hover_color", "Button", INK)
	theme.set_color("font_pressed_color", "Button", INK)
	theme.set_color("font_focus_color", "Button", CREAM)
	theme.set_stylebox("normal", "Button", _style(Color("244251"), 10))
	theme.set_stylebox("hover", "Button", _style(MINT, 10))
	theme.set_stylebox("pressed", "Button", _style(GOLD, 10))
	theme.set_stylebox("focus", "Button", _style(Color(0, 0, 0, 0), 10, GOLD))
	theme.set_stylebox("panel", "PanelContainer", _style(Color(0.065, 0.14, 0.18, 0.96), 16, Color("37535b")))
	theme.set_stylebox("normal", "LineEdit", _style(Color("244251"), 8))
	theme.set_color("font_color", "LineEdit", CREAM)
	theme.set_stylebox("background", "ProgressBar", _style(Color("2c4650"), 3))
	theme.set_stylebox("fill", "ProgressBar", _style(MINT, 3))
	theme.set_constant("separation", "VBoxContainer", 9)
	theme.set_constant("separation", "HBoxContainer", 9)
	ui.theme = theme

func _apply_safe_area() -> void:
	if not OS.has_feature("android"):
		return
	var safe = DisplayServer.get_display_safe_area()
	var window = DisplayServer.window_get_size()
	if window.x <= 0 or window.y <= 0 or safe.size.x <= 0:
		return
	var ratio = get_viewport_rect().size / Vector2(window)
	ui.offset_left = maxf(0, safe.position.x) * ratio.x
	ui.offset_top = maxf(0, safe.position.y) * ratio.y
	ui.offset_right = -maxf(0, window.x - safe.end.x) * ratio.x
	ui.offset_bottom = -maxf(0, window.y - safe.end.y) * ratio.y

func _style(color: Color, radius: int = 8, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	if border.a > 0:
		s.set_border_width_all(1)
		s.border_color = border
	return s

func _label(text: String, size: int = 15, color: Color = CREAM) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _paragraph(text: String, color: Color = MUTED) -> Label:
	var label = _label(text, 14, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

func _button(text: String, callback: Callable, primary: bool = false) -> Button:
	var button = Button.new()
	button.text = text
	button.custom_minimum_size.y = 44
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(callback)
	if primary:
		button.add_theme_stylebox_override("normal", _style(GOLD, 10))
		button.add_theme_color_override("font_color", INK)
	return button

func _row(parent: Node) -> HBoxContainer:
	var row = HBoxContainer.new()
	parent.add_child(row)
	return row

func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func _create_hud() -> void:
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(hud)
	var top = PanelContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 20
	top.offset_right = -20
	top.offset_top = 16
	hud.add_child(top)
	var row = _row(top)
	var brand = _button("B / 17", _open_pause)
	brand.add_theme_font_size_override("font_size", 22)
	brand.add_theme_color_override("font_color", GOLD)
	row.add_child(brand)
	var time_box = VBoxContainer.new()
	time_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(time_box)
	time_box.add_child(_label("ЖИВОЙ ГОРОДСКОЙ РАЙОН", 10, MUTED))
	clock_label = _label("День 1 · 07:00", 19)
	time_box.add_child(clock_label)
	population_label = _label("120 жителей", 16)
	row.add_child(population_label)
	var spacer = Control.new()
	spacer.custom_minimum_size.x = 12
	row.add_child(spacer)
	mood_label = _label("Настроение 76%", 16, MINT)
	row.add_child(mood_label)
	budget_label = _label("180 000 ₽", 19, GOLD)
	budget_label.custom_minimum_size.x = 160
	budget_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(budget_label)
	for value in [0, 1, 2, 4]:
		var v = value
		var button = _button("Ⅱ" if value == 0 else str(value) + "×", func(): _set_speed(v))
		button.custom_minimum_size.x = 46
		row.add_child(button)
		speed_buttons[value] = button
	var footer = PanelContainer.new()
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_left = 20
	footer.offset_right = -20
	footer.offset_top = -86
	footer.offset_bottom = -16
	hud.add_child(footer)
	var dock = _row(footer)
	for entry in [["Строить", _show_build], ["Жители", _show_residents], ["Экономика", _show_economy], ["Газета", _show_news], ["Бюджет", _show_budget], ["Сохранить", _show_saves]]:
		var button = _button(entry[0], entry[1])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		dock.add_child(button)
	var zoom_out = _button("−", func(): city.zoom_by(1.0 / 1.2))
	zoom_out.custom_minimum_size.x = 48
	dock.add_child(zoom_out)
	var zoom_in = _button("+", func(): city.zoom_by(1.2))
	zoom_in.custom_minimum_size.x = 48
	dock.add_child(zoom_in)
	var headline = PanelContainer.new()
	headline.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	headline.position = Vector2(20, 106)
	headline.custom_minimum_size = Vector2(285, 82)
	headline.size = Vector2(285, 82)
	hud.add_child(headline)
	var news_box = VBoxContainer.new()
	headline.add_child(news_box)
	news_box.add_child(_label("РАЙОННАЯ ХРОНИКА", 10, GOLD))
	news_label = _paragraph("Город просыпается. Коснитесь жителя, чтобы узнать его историю.", CREAM)
	news_label.custom_minimum_size.x = 250
	news_label.max_lines_visible = 2
	news_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	news_box.add_child(news_label)
	var reset = _button("⌂  Весь район", func(): city.following = -1; city.target_position = Vector2(0, 450); city.target_zoom = 0.48)
	reset.position = Vector2(20, 202)
	hud.add_child(reset)
	_set_speed(1)

func _create_side() -> void:
	side = PanelContainer.new()
	side.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	side.offset_left = -414
	side.offset_right = -20
	side.offset_top = 106
	side.offset_bottom = -102
	ui.add_child(side)
	side.visible = false

func _panel(title: String, subtitle: String = "") -> VBoxContainer:
	selected_type = ""
	city.set_build_mode(false)
	_clear(side)
	side.show()
	ui.move_child(side, -1)
	var outer = VBoxContainer.new()
	side.add_child(outer)
	var top = _row(outer)
	var heading = _label(title, 24)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(heading)
	top.add_child(_button("×", _close_panel))
	if subtitle != "":
		outer.add_child(_paragraph(subtitle))
	var separator = HSeparator.new()
	outer.add_child(separator)
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	panel_content = VBoxContainer.new()
	panel_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_content.add_theme_constant_override("separation", 12)
	scroll.add_child(panel_content)
	return panel_content

func _close_panel() -> void:
	side.hide()
	panel_kind = ""
	selected_type = ""
	city.set_build_mode(false)
	city.select_building(-1)

func _create_toast() -> void:
	toast_label = _label("", 16, INK)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.add_theme_stylebox_override("normal", _style(GOLD, 10))
	toast_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	toast_label.offset_left = -340
	toast_label.offset_right = 340
	toast_label.offset_top = -148
	toast_label.offset_bottom = -104
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(toast_label)
	toast_label.hide()

func _toast(message: String) -> void:
	toast_label.text = message
	toast_time = 4
	toast_label.show()
	ui.move_child(toast_label, -1)

func _show_menu() -> void:
	running = false
	city.active = false
	hud.hide()
	side.hide()
	if is_instance_valid(menu):
		menu.queue_free()
	menu = Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(menu)
	var shade = ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.025, 0.07, 0.10, 0.36)
	menu.add_child(shade)
	var panel = PanelContainer.new()
	panel.position = Vector2(44, 40)
	panel.size = Vector2(405, 630)
	menu.add_child(panel)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 9)
	panel.add_child(box)
	box.add_child(_label("ИСТОРИИ ОДНОГО РАЙОНА", 12, MINT))
	box.add_child(_label("BLOCK", 70))
	var number = _label("17", 124, GOLD)
	number.add_theme_constant_override("outline_size", 0)
	box.add_child(number)
	box.add_child(_paragraph("Город живёт. Люди выбирают.\nА вы меняете их будущее.", CREAM))
	box.add_child(_button("Новая игра", _confirm_new, true))
	var continue_button = _button("Продолжить", _continue_game)
	continue_button.disabled = not running and Store.load_city("autosave").has("error") and day_is_new()
	box.add_child(continue_button)
	box.add_child(_button("Загрузить", _show_loads))
	box.add_child(_button("Настройки", _show_settings))
	box.add_child(_label("ОФЛАЙН · БЕЗ РЕКЛАМЫ · 120 ЖИЗНЕЙ", 10, MUTED))
	var caption = _label("Каждый освещённый дом —\nчья-то история.", 24, CREAM)
	caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	caption.offset_left = -420
	caption.offset_top = -125
	caption.offset_right = -45
	caption.offset_bottom = -40
	menu.add_child(caption)

func day_is_new() -> bool:
	return sim.day == 1 and sim.minute == 420

func _confirm_new() -> void:
	if day_is_new():
		_new_game()
		return
	var content = _panel("Новый район", "Текущий город останется в автосохранении. Создать новый?")
	content.add_child(_button("Создать район", _new_game, true))
	content.add_child(_button("Назад", _close_panel))

func _new_game() -> void:
	sim = Simulation.new()
	sim.new_city(int(Time.get_unix_time_from_system()) % 2000000000)
	city.bind(sim)
	city.following = -1
	city.selected_person = -1
	city.target_position = Vector2(0, 510)
	city.target_zoom = 0.72
	selected_resident = -1
	accumulator = 0
	_start_game()
	_toast("Добро пожаловать! Выберите жителя или откройте строительство.")

func _start_game() -> void:
	if is_instance_valid(menu):
		menu.hide()
	_close_panel()
	hud.show()
	running = true
	city.active = true
	_set_speed(1)
	_refresh_hud()

func _continue_game() -> void:
	if not day_is_new():
		_start_game()
	else:
		_load_slot("autosave")

func _open_pause() -> void:
	_previous_save()
	_show_menu()

func _previous_save() -> void:
	if running:
		_save_slot("autosave", false)

func _set_speed(value: int) -> void:
	speed = value
	if value > 0:
		previous_speed = value
	for key in speed_buttons:
		var button: Button = speed_buttons[key]
		button.add_theme_stylebox_override("normal", _style(GOLD if key == value else Color("244251"), 8))
		button.add_theme_color_override("font_color", INK if key == value else CREAM)

func _process(delta: float) -> void:
	if running and speed > 0:
		accumulator += minf(delta, 0.25) * 10.0 * speed
		var steps = mini(int(accumulator), 12)
		if steps > 0:
			sim.advance(steps)
			accumulator -= steps
	refresh_time += delta
	if refresh_time >= 0.5:
		refresh_time = 0
		if running:
			_refresh_hud()
			if panel_kind == "person":
				_refresh_person()
	if running:
		autosave_time += delta
		if autosave_time >= 60:
			autosave_time = 0
			_save_slot("autosave", false)
	if toast_time > 0:
		toast_time -= delta
		if toast_time <= 0:
			toast_label.hide()
	_feed_audio()

func _refresh_hud() -> void:
	var stats = sim.stats()
	clock_label.text = "День %d · %02d:%02d%s" % [sim.day, sim.minute / 60, sim.minute % 60, " · пауза" if speed == 0 else ""]
	population_label.text = "%d жителей" % stats.population
	mood_label.text = "Настроение %d%%" % stats.mood
	budget_label.text = Catalog.money(sim.treasury)
	if not sim.events.is_empty():
		news_label.text = sim.events[0].title + ". " + sim.events[0].body.left(90)

func _show_build() -> void:
	panel_kind = "build"
	var box = _panel("Новые места", "Выберите проект, затем свободный участок с «+» на карте. Стоимость списывается после размещения.")
	city.set_build_mode(true)
	for kind in Catalog.TYPES:
		var key = kind
		var info: Dictionary = Catalog.TYPES[kind]
		var card = VBoxContainer.new()
		box.add_child(card)
		var button = _button(info.name + " · " + Catalog.money(info.cost), func(): _select_project(key))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 14)
		card.add_child(button)
		card.add_child(_paragraph(info.description))

func _select_project(kind: String) -> void:
	selected_type = kind
	city.set_build_mode(true)
	_toast("%s: коснитесь свободного участка" % Catalog.TYPES[kind].name)

func _on_ground(cell: Vector2i) -> void:
	if selected_type == "":
		if panel_kind == "build":
			_toast("Сначала выберите проект справа")
		return
	var error = sim.build_at(selected_type, cell)
	if error != "":
		_toast(error)
	else:
		_toast("Построено: " + Catalog.TYPES[selected_type].name)
		city.refresh()
		_refresh_hud()

func _show_residents() -> void:
	selected_type = ""
	city.set_build_mode(false)
	panel_kind = "residents"
	var box = _panel("Люди района", "У каждого есть дом, работа и мечта. Выберите имя, чтобы открыть историю.")
	var search = LineEdit.new()
	search.placeholder_text = "Поиск по имени или профессии"
	search.custom_minimum_size.y = 44
	box.add_child(search)
	var list = VBoxContainer.new()
	box.add_child(list)
	var fill = func(query: String):
		_clear(list)
		for r in sim.residents:
			if query != "" and not (r.name + " " + r.profession).to_lower().contains(query.to_lower()):
				continue
			var id: int = r.id
			var button = _button("%s · %d\n%s · %s" % [r.name, r.age, r.profession, Catalog.money(r.money)], func(): _show_person(id))
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.add_theme_font_size_override("font_size", 14)
			list.add_child(button)
	search.text_changed.connect(fill)
	fill.call("")

func _show_person(id: int) -> void:
	selected_resident = id
	selected_type = ""
	city.set_build_mode(false)
	city.selected_person = id
	panel_kind = "person"
	var r: Dictionary = sim.residents[id]
	person_version = _person_version(r)
	var box = _panel(r.name, "%d лет · %s · %s" % [r.age, r.trait, r.profession])
	person_labels.clear()
	var controls = _row(box)
	var follow_button = _button("Следить камерой", func(): city.focus_person(id, true); _toast("Камера следует за жителем. Перетащите карту, чтобы остановить."))
	follow_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(follow_button)
	controls.add_child(_button("Найти", func(): city.focus_person(id)))
	for key in ["activity", "money", "home", "work", "goal", "family"]:
		var label = _paragraph("", CREAM if key == "activity" else MUTED)
		box.add_child(label)
		person_labels[key] = label
	for key in ["mood", "food", "energy", "social", "health"]:
		var row = _row(box)
		var title = _label({"mood": "Настроение", "food": "Сытость", "energy": "Энергия", "social": "Общение", "health": "Здоровье"}[key], 13, MUTED)
		title.custom_minimum_size.x = 108
		row.add_child(title)
		var bar = ProgressBar.new()
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.custom_minimum_size.y = 15
		bar.show_percentage = false
		row.add_child(bar)
		person_labels[key] = bar
	box.add_child(_label("ДРУЗЬЯ И БЛИЗКИЕ", 12, GOLD))
	var relations = []
	if r.partner >= 0:
		relations.append([r.partner, "Партнёр"])
	for friend in r.friends:
		relations.append([friend, "Друг"])
	for relative in r.family:
		if relative != r.partner:
			relations.append([relative, "Родственник"])
	for rival in r.rivals:
		relations.append([rival, "Конфликт"])
	for relation in relations:
		var other_id = int(relation[0])
		box.add_child(_button("%s · %s" % [relation[1], sim.residents[other_id].name], func(): _show_person(other_id)))
	box.add_child(_label("ЛИЧНЫЙ ДНЕВНИК", 12, GOLD))
	for entry in r.history:
		box.add_child(_paragraph("День %d · %02d:%02d\n%s" % [entry.day, int(entry.minute) / 60, int(entry.minute) % 60, entry.text]))
	_refresh_person()

func _refresh_person() -> void:
	if selected_resident < 0 or not person_labels.has("activity"):
		return
	var r: Dictionary = sim.residents[selected_resident]
	var version = _person_version(r)
	if version != person_version:
		person_version = version
		var scroll = panel_content.get_parent() as ScrollContainer
		call_deferred("_refresh_person_panel", selected_resident, scroll.scroll_vertical)
	person_labels.activity.text = r.activity + (" · камера следует" if city.following == r.id else "")
	person_labels.money.text = "Сбережения: %s\nЗа день: +%s / −%s\nАренда: %s в день" % [Catalog.money(r.money), Catalog.money(r.income), Catalog.money(r.expenses), Catalog.money(r.rent)]
	var home: Dictionary = sim.buildings[r.home]
	person_labels.home.text = "Дом: %s, %s, № %d" % [Catalog.TYPES[home.type].name, sim.streets[mini(home.y / 4, 5)].name, home.id + 1]
	person_labels.work.text = "Работа: %s · %s в день" % [Catalog.TYPES[sim.buildings[r.work].type].name, Catalog.money(r.salary)] if r.work >= 0 else "Занятие: " + r.profession
	person_labels.goal.text = ("Мечта исполнена: " if r.goal_done else "Мечта: ") + r.goal
	person_labels.family.text = "%d друзей · %d родственников · %d конфликтов" % [r.friends.size(), r.family.size(), r.rivals.size()]
	for key in ["mood", "food", "energy", "social", "health"]:
		person_labels[key].value = r[key]

func _person_version(r: Dictionary) -> String:
	return "%s/%s/%s/%s/%s" % [r.history.hash(), r.friends.hash(), r.rivals.hash(), r.partner, r.work]

func _refresh_person_panel(id: int, scroll_position: int) -> void:
	if panel_kind != "person" or selected_resident != id or not side.visible:
		return
	_show_person(id)
	var scroll = panel_content.get_parent() as ScrollContainer
	scroll.set_deferred("scroll_vertical", scroll_position)

func _show_building(id: int) -> void:
	selected_type = ""
	city.set_build_mode(false)
	city.select_building(id)
	panel_kind = "building"
	var b: Dictionary = sim.buildings[id]
	var info: Dictionary = Catalog.TYPES[b.type]
	var box = _panel(info.name, "%s · дом %d" % [sim.streets[mini(b.y / 4, 5)].name, id + 1])
	box.add_child(_paragraph(info.description, CREAM))
	_metric(box, "Счёт предприятия", Catalog.money(b.cash))
	_metric(box, "Результат прошлого дня", Catalog.money(b.profit))
	_metric(box, "Работники / места", "%d / %d" % [sim.workers(id), info.jobs])
	_metric(box, "Мест для жителей", str(info.homes))
	if b.owner >= 0:
		var owner = int(b.owner)
		box.add_child(_button("Владелец: " + sim.residents[owner].name, func(): _show_person(owner)))
	if info.jobs > 0 and b.type not in ["clinic", "school"]:
		box.add_child(_button("Поддержать бизнес · 3 000 ₽", func():
			if sim.treasury < 3000:
				_toast("В бюджете недостаточно средств")
				return
			sim.treasury -= 3000
			sim.daily_expense += 3000
			b.cash += 3000
			b.closed = false
			b.loss_days = 0
			_show_building(id)
			_toast("Предприятие получило поддержку")))
	box.add_child(_label("ЛЮДИ ЭТОГО МЕСТА", 12, GOLD))
	for r in sim.residents:
		if r.home == id or r.work == id:
			var person = int(r.id)
			box.add_child(_button(r.name + " · " + ("Живёт здесь" if r.home == id else r.profession), func(): _show_person(person)))

func _metric(parent: Node, name_text: String, value_text: String) -> void:
	var row = _row(parent)
	var name_label = _label(name_text, 13, MUTED)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	row.add_child(_label(value_text, 16, GOLD))

func _show_economy() -> void:
	panel_kind = "economy"
	var stats = sim.stats()
	var box = _panel("Экономика", "Снимок текущего состояния. Зарплаты — в 18:00, аренда и содержание — в 21:00.")
	_metric(box, "Заняты / трудоспособны", "%d / %d" % [stats.employed, stats.workforce])
	_metric(box, "Безработица", "%.1f%%" % stats.unemployment)
	_metric(box, "Рабочие места", str(stats.jobs))
	_metric(box, "Жители / жильё", "%d / %d" % [stats.population, stats.capacity])
	_metric(box, "Давление на аренду", "×%.2f" % stats.rent)
	_metric(box, "Сбережения жителей", Catalog.money(stats.wealth))
	_metric(box, "Покупок с начала игры", str(stats.purchases))
	box.add_child(_paragraph("Офисы и мастерские привозят деньги через внешние заказы. Магазины и кафе зависят от покупок. Пустые кассы приводят к сокращениям. Новое жильё снижает арендную нагрузку."))
	box.add_child(_button("Обновить показатели", _show_economy))
	box.add_child(_label("УЛИЦЫ РАЙОНА", 12, GOLD))
	for street in sim.streets:
		_metric(box, street.name, "%d / 100" % street.quality)

func _show_budget() -> void:
	panel_kind = "budget"
	var box = _panel("Городская казна", "Город оплачивает школы, медицину, пособия, дороги и парки. Доход — налоги с зарплат и аренды.")
	_metric(box, "Остаток", Catalog.money(sim.treasury))
	_metric(box, "Доходы сегодня", Catalog.money(sim.daily_income))
	_metric(box, "Расходы сегодня", Catalog.money(sim.daily_expense))
	_metric(box, "Вчера: доход / расход", "%s / %s" % [Catalog.money(sim.last_income), Catalog.money(sim.last_expense)])
	box.add_child(_label("НАЛОГ НА ДОХОДЫ", 12, GOLD))
	var row = _row(box)
	for rate in [0.08, 0.12, 0.18]:
		var value: float = rate
		var button = _button("%d%%" % (rate * 100), func(): sim.tax_rate = value; _show_budget(), is_equal_approx(rate, sim.tax_rate))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(button)
	box.add_child(_paragraph("Высокий налог пополняет казну и уменьшает деньги на руках у жителей. Они смогут реже ходить в кафе и медленнее накопят на бизнес."))
	box.add_child(_button("Обновить бюджет", _show_budget))
	box.add_child(_label("ИСТОРИЯ БЮДЖЕТА", 12, GOLD))
	if sim.ledger.is_empty():
		box.add_child(_paragraph("Первый отчёт появится после полуночи."))
	for i in range(sim.ledger.size() - 1, maxi(-1, sim.ledger.size() - 8), -1):
		var entry: Dictionary = sim.ledger[i]
		box.add_child(_paragraph("День %d: +%s / −%s\nОстаток %s" % [entry.day, Catalog.money(entry.income), Catalog.money(entry.expense), Catalog.money(entry.balance)]))

func _show_news() -> void:
	panel_kind = "news"
	var box = _panel("Вестник BLOCK 17", "Газета рождается из событий города. Нажмите на историю человека, чтобы открыть его карточку.")
	box.add_child(_button("Свежий выпуск", _show_news))
	for entry in sim.events:
		box.add_child(_label("ДЕНЬ %d · %02d:%02d · %s" % [entry.day, int(entry.minute) / 60, int(entry.minute) % 60, entry.category.to_upper()], 10, GOLD))
		var title = _paragraph(entry.title, CREAM)
		title.add_theme_font_size_override("font_size", 19)
		box.add_child(title)
		box.add_child(_paragraph(entry.body))
		if entry.person >= 0:
			var id = int(entry.person)
			box.add_child(_button("Открыть историю", func(): _show_person(id)))
		box.add_child(HSeparator.new())

func _show_saves() -> void:
	panel_kind = "save"
	var box = _panel("Сохранить город", "Три ручных слота и отдельное автосохранение. Город сохраняется также при сворачивании игры.")
	for slot in ["slot1", "slot2", "slot3"]:
		var key = slot
		var data = Store.metadata(slot)
		var summary = "Пусто" if data.has("error") else "День %d · %s" % [data.day, Catalog.money(data.budget)]
		box.add_child(_paragraph("Слот %s · %s" % [slot.right(1), summary]))
		box.add_child(_button("Записать в слот " + slot.right(1), func(): _save_slot(key); _show_saves()))
	box.add_child(_button("Загрузить город", _show_loads))

func _show_loads() -> void:
	panel_kind = "load"
	var box = _panel("Загрузить город", "Выберите сохранение. Текущий город будет заменён выбранным.")
	for slot in Store.SLOTS:
		var key = slot
		var data = Store.metadata(slot)
		var name_text = "Автосохранение" if slot == "autosave" else "Слот " + slot.right(1)
		var button = _button(name_text + (" · пусто" if data.has("error") else " · день %d" % data.day), func(): _load_slot(key))
		button.disabled = data.has("error")
		box.add_child(button)
		if not data.has("error"):
			box.add_child(_paragraph("%02d:%02d · %d жителей · %s" % [data.minute / 60, data.minute % 60, data.population, Catalog.money(data.budget)]))

func _save_slot(slot: String, announce: bool = true) -> void:
	var extra = {"camera": [city.target_position.x, city.target_position.y], "zoom": city.target_zoom}
	var error = Store.save_city(sim, slot, extra)
	if error != OK:
		_toast("Не удалось сохранить город: " + error_string(error))
	elif announce:
		_toast("Город сохранён")

func _load_slot(slot: String) -> void:
	var data = Store.load_city(slot)
	if data.has("error"):
		_toast(data.error)
		return
	sim = Simulation.new()
	sim.restore(data.simulation)
	city.bind(sim)
	city.following = -1
	city.selected_person = -1
	selected_resident = -1
	var extra: Dictionary = data.get("extra", {})
	if extra.has("camera") and extra.camera is Array and extra.camera.size() == 2:
		city.target_position = Vector2(extra.camera[0], extra.camera[1])
	city.target_zoom = clampf(extra.get("zoom", 0.72), 0.4, 2.25)
	accumulator = 0
	_start_game()
	_toast("Восстановлена резервная копия" if data.get("recovered", false) else "Город восстановлен")

func _show_settings() -> void:
	panel_kind = "settings"
	var box = _panel("Настройки", "Управление: перетаскивание — камера; два пальца — масштаб; касание — выбор. Игра работает без интернета.")
	for entry in [["ambience", "Звуки города"], ["low_detail", "Экономия энергии (меньше машин)"]]:
		var key: String = entry[0]
		var check = CheckButton.new()
		check.text = entry[1]
		check.button_pressed = settings[key]
		check.custom_minimum_size.y = 48
		check.toggled.connect(func(value: bool): settings[key] = value; city.low_detail = settings.low_detail; _save_settings())
		box.add_child(check)
	box.add_child(_paragraph("Пейзаж / OpenGL ES 3 · Godot 4.6.3\nВерсия 0.1.0 · BLOCK 17\nАвторы: проект elcin31/BLOCK-17"))
	box.add_child(_button("Как живёт район", _show_help))

func _show_help() -> void:
	var box = _panel("Ваш первый день", "Город движется сам. Ваша задача — дать людям возможности.")
	for text in ["1. Откройте «Жители» и выберите человека. Кнопка «Следить камерой» покажет его путь на работу и в магазин.", "2. Постройте офис или мастерскую, чтобы увеличить занятость. Магазину нужны покупатели: новые лавки конкурируют за их деньги.", "3. Добавьте дом, чтобы снизить давление на аренду. Сквер даёт отдых и место для знакомств.", "4. В 18:00 начисляют зарплаты, в 19:00 люди знакомятся, в 21:00 платят аренду. В газете остаются истории.", "5. Следите за бюджетом. Школа, поликлиника и пособия требуют средств. Можно изменить налог или поддержать убыточный бизнес.", "6. Сохраняйтесь вручную в один из трёх слотов. Автосохранение работает раз в минуту и при сворачивании."]:
		box.add_child(_paragraph(text, CREAM))

func _load_settings() -> void:
	var config = ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		for key in settings:
			settings[key] = bool(config.get_value("game", key, settings[key]))

func _save_settings() -> void:
	var config = ConfigFile.new()
	for key in settings:
		config.set_value("game", key, settings[key])
	config.save("user://settings.cfg")

func _create_audio() -> void:
	# Original procedural soundscape, precomputed to avoid per-frame audio generation.
	if AudioServer.get_driver_name() == "Dummy":
		return
	audio = AudioStreamPlayer.new()
	var stream = preload("res://assets/city-ambience.wav")
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
	audio.stream = stream
	audio.volume_db = -28
	add_child(audio)
	audio.play()

func _feed_audio() -> void:
	if audio == null:
		return
	audio.volume_db = -28.0 if settings.ambience else -80.0
	audio.pitch_scale = 0.85 if city.is_night else 1.0

func _exit_tree() -> void:
	if is_instance_valid(audio):
		audio.stop()
		audio.stream = null

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if running:
			_save_slot("autosave", false)
		if what == NOTIFICATION_APPLICATION_PAUSED:
			_set_speed(0)
		else:
			get_tree().quit()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if side != null and side.visible:
			_close_panel()
		elif running:
			_open_pause()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE and running:
			_set_speed(previous_speed if speed == 0 else 0)
		elif event.keycode == KEY_ESCAPE:
			if side.visible:
				_close_panel()
			elif running:
				_open_pause()
