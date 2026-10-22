extends SceneTree
var checks: int = 0
var failures: int = 0
var game

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, text: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + text)

func shot(name_text: String) -> void:
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://builds/" + name_text + ".png")

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	check(game.menu.visible and not game.hud.visible, "main menu appears")
	await shot("01-menu")
	game._show_settings()
	check(game.side.visible, "settings opens from main menu")
	game._close_panel()
	game._new_game()
	check(game.running and game.hud.visible, "new game starts")
	game._set_speed(0)
	var minute = game.sim.minute
	await process_frame
	check(game.sim.minute == minute, "pause stops simulation")
	for speed in [1, 2, 4]:
		game._set_speed(speed)
		check(game.speed == speed, "speed button changes speed")
	game._set_speed(0)
	game.sim.advance(100)
	await shot("02-city")
	game._show_residents()
	check(game.panel_kind == "residents", "resident list opens")
	game._show_person(0)
	check(game.person_labels.activity.text != "", "person card populated")
	game.city.focus_person(0, true)
	check(game.city.following == 0, "camera follows selected resident")
	await shot("03-resident")
	game._show_build()
	game._select_project("home")
	var old = game.sim.buildings.size()
	game._on_ground(Vector2i(18, 2))
	check(game.sim.buildings.size() == old + 1, "UI construction mutates simulation")
	game._show_economy()
	check(not game.city.building_mode and game.selected_type == "", "other panels leave build mode")
	game._show_budget()
	check(game.panel_kind == "budget", "budget opens")
	game._show_building(0)
	check(game.city.selected_building == 0, "building selectable")
	game._show_news()
	check(game.panel_kind == "news", "newspaper opens")
	game._show_saves()
	game._save_slot("slot2", false)
	var old_time = game.sim.minute
	game.sim.advance(10)
	game._load_slot("slot2")
	game._set_speed(0)
	check(game.sim.minute == old_time, "load restores complete city via UI")
	game.sim.minute = 1260
	game._close_panel()
	game.city.target_position = Vector2(0, 510)
	game.city.target_zoom = 0.72
	game.city.following = -1
	await create_timer(0.4).timeout
	await shot("04-night")
	root.size = Vector2i(1600, 720)
	await process_frame
	check(game.ui.size.x >= 1280, "wide Android viewport adapts")
	game._show_settings()
	await shot("05-wide")
	game._close_panel()
	game._show_menu()
	check(not game.running and game.menu.visible, "pause menu stops city")
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveStore.path_for("slot2") + suffix))
	print("UI: %d checks, %d failures" % [checks, failures])
	game.free()
	await process_frame
	quit(1 if failures else 0)
