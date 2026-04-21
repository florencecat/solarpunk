extends Node3D

# ─── Узлы мира ────────────────────────────────────────────────────────────────
var _camera:  Camera3D
var _sun:     DirectionalLight3D
var _env_res: Environment

# ─── Вращение камеры ──────────────────────────────────────────────────────────
const CAM_HEIGHT: float = 20.0
const CAM_DIST:   float = 14.0
const CAM_SPEED:  float = 1.5    # рад/сек

var _cam_yaw: float = 0.0

func _ready() -> void:
	_create_world()
	_create_managers()
	_create_map()
	_create_ui()
	_emit_initial_state()
	EventBus.turn_ended.connect(_on_turn_ended)

# ─── Мир (камера, свет, окружение) ───────────────────────────────────────────

func _create_world() -> void:
	var env_node      = WorldEnvironment.new()
	env_node.name     = "WorldEnvironment"
	_env_res          = Environment.new()
	_env_res.background_mode    = Environment.BG_COLOR
	_env_res.background_color   = Color(0.60, 0.46, 0.24)
	_env_res.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env_res.ambient_light_color  = Color(0.88, 0.74, 0.52)
	_env_res.ambient_light_energy = 0.42
	env_node.environment = _env_res
	add_child(env_node)

	_sun                   = DirectionalLight3D.new()
	_sun.name              = "Sun"
	_sun.rotation_degrees  = Vector3(-52.0, 28.0, 0.0)
	_sun.light_energy      = 1.15
	_sun.shadow_enabled    = true
	_sun.shadow_bias       = 0.04
	add_child(_sun)

	var fill               = DirectionalLight3D.new()
	fill.name              = "FillLight"
	fill.rotation_degrees  = Vector3(-22.0, -148.0, 0.0)
	fill.light_energy      = 0.28
	add_child(fill)

	_camera            = Camera3D.new()
	_camera.name       = "Camera3D"
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size       = 16.0
	add_child(_camera)
	_update_camera_position()

# ─── Вращение камеры ─────────────────────────────────────────────────────────

func _update_camera_position() -> void:
	_camera.position = Vector3(
		sin(_cam_yaw) * CAM_DIST,
		CAM_HEIGHT,
		cos(_cam_yaw) * CAM_DIST
	)
	_camera.look_at(Vector3.ZERO)

func _process(delta: float) -> void:
	var rot := 0.0
	if Input.is_key_pressed(KEY_Q): rot -= 1.0
	if Input.is_key_pressed(KEY_E): rot += 1.0
	if rot != 0.0:
		_cam_yaw += rot * CAM_SPEED * delta
		_update_camera_position()

# ─── Менеджеры ───────────────────────────────────────────────────────────────

func _create_managers() -> void:
	var rm = ResourceManager.new()
	var pm = PopulationManager.new()
	var wm = WorkerManager.new()
	var em = EventManager.new()
	var lm = LawsManager.new()
	var tm = TurnManager.new()

	rm.name = "ResourceManager"
	pm.name = "PopulationManager"
	wm.name = "WorkerManager"
	em.name = "EventManager"
	lm.name = "LawsManager"
	tm.name = "TurnManager"

	add_child(rm)
	add_child(pm)
	add_child(wm)
	add_child(em)
	add_child(lm)
	add_child(tm)

	tm.add_to_group("turn_manager")
	tm.setup(rm, pm, wm, em)
	set_meta("laws_manager", lm)

# ─── Карта ───────────────────────────────────────────────────────────────────

func _create_map() -> void:
	var map  = HexMap.new()
	map.name = "HexMap"
	add_child(map)

# ─── Интерфейс ───────────────────────────────────────────────────────────────

func _create_ui() -> void:
	var ui  = CanvasLayer.new()
	ui.name = "UI"
	add_child(ui)

	var hud = load("res://scripts/ui/hud.gd").new()
	hud.name = "HUD"
	hud.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	hud.custom_minimum_size = Vector2(960.0, 140.0)
	ui.add_child(hud)

	var elog = load("res://scripts/ui/event_log.gd").new()
	elog.name = "EventLog"
	elog.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	elog.offset_left   = -318.0
	elog.offset_top    = -248.0
	elog.offset_right  =   -8.0
	elog.offset_bottom =   -8.0
	ui.add_child(elog)

	var bld = load("res://scripts/ui/building_panel.gd").new()
	bld.name = "BuildingPanel"
	bld.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	bld.offset_left   = -215.0
	bld.offset_top    = -310.0
	bld.offset_right  =   -8.0
	bld.offset_bottom =  310.0
	ui.add_child(bld)

	var laws = load("res://scripts/ui/laws_panel.gd").new()
	laws.name = "LawsPanel"
	laws.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	laws.offset_left   =   8.0
	laws.offset_top    = -185.0
	laws.offset_right  =  235.0
	laws.offset_bottom =  185.0
	ui.add_child(laws)
	laws.call_deferred("setup", get_meta("laws_manager"))

	var tip = load("res://scripts/ui/tile_info_panel.gd").new()
	tip.name = "TileInfoPanel"
	tip.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	tip.offset_left   = -220.0
	tip.offset_top    = -165.0
	tip.offset_right  =  220.0
	tip.offset_bottom =   -8.0
	ui.add_child(tip)

# ─── Ввод: зум колёсиком ─────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_camera.size = maxf(7.0, _camera.size - 0.9)
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_camera.size = minf(28.0, _camera.size + 0.9)

# ─── Эффект песчаной бури ────────────────────────────────────────────────────

func _on_turn_ended(_t: int) -> void:
	if GameState.sandstorm_active:
		_env_res.ambient_light_color  = Color(0.95, 0.72, 0.20)
		_env_res.ambient_light_energy = 0.65
		_sun.light_energy             = 0.55
		_sun.light_color              = Color(0.98, 0.80, 0.42)
	else:
		_env_res.ambient_light_color  = Color(0.88, 0.74, 0.52)
		_env_res.ambient_light_energy = 0.42
		_sun.light_energy             = 1.15
		_sun.light_color              = Color.WHITE

# ─── Первоначальное состояние ────────────────────────────────────────────────

func _emit_initial_state() -> void:
	EventBus.turn_ended.emit(0)
	EventBus.water_changed.emit(GameState.water, 0.0)
	EventBus.population_changed.emit(GameState.population)
	EventBus.happiness_changed.emit(
		GameState.happiness, GameState.thirst, GameState.discontent)
	EventBus.resources_changed.emit(GameState.sand, GameState.scrap, GameState.diamonds)
	EventBus.game_event.emit({
		"turn":        0,
		"title":       "Поселение основано",
		"description": "Вы нашли оазис посреди пустыни. " +
					   "Стройте насосы, следите за запасами воды — " +
					   "пока жара не убила всех.",
		"severity":    0,
	})
