extends Node2D

func _ready() -> void:
	_create_managers()
	_create_map()
	_create_ui()
	_emit_initial_state()

# ─── Менеджеры ───────────────────────────────────────────────────────────────

func _create_managers() -> void:
	var rm = ResourceManager.new()
	var pm = PopulationManager.new()
	var em = EventManager.new()
	var lm = LawsManager.new()
	var tm = TurnManager.new()

	rm.name = "ResourceManager"
	pm.name = "PopulationManager"
	em.name = "EventManager"
	lm.name = "LawsManager"
	tm.name = "TurnManager"

	add_child(rm)
	add_child(pm)
	add_child(em)
	add_child(lm)
	add_child(tm)

	tm.add_to_group("turn_manager")
	tm.setup(rm, pm, em)

	set_meta("laws_manager", lm)

# ─── Карта ───────────────────────────────────────────────────────────────────

func _create_map() -> void:
	var map = HexMap.new()
	map.name     = "HexMap"
	map.position = Vector2(640.0, 390.0)   # центр экрана 1280×720, чуть ниже
	add_child(map)

# ─── Интерфейс ───────────────────────────────────────────────────────────────

func _create_ui() -> void:
	var ui = CanvasLayer.new()
	ui.name = "UI"
	add_child(ui)

	# HUD — верхний левый угол
	var hud = load("res://scripts/ui/hud.gd").new()
	hud.name = "HUD"
	hud.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	hud.custom_minimum_size = Vector2(720.0, 140.0)
	ui.add_child(hud)

	# Журнал событий — правый нижний угол
	var elog = load("res://scripts/ui/event_log.gd").new()
	elog.name = "EventLog"
	elog.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	elog.offset_left   = -318.0
	elog.offset_top    = -248.0
	elog.offset_right  = -8.0
	elog.offset_bottom = -8.0
	ui.add_child(elog)

	# Панель построек — правый центр
	var bld = load("res://scripts/ui/building_panel.gd").new()
	bld.name = "BuildingPanel"
	bld.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	bld.offset_left   = -215.0
	bld.offset_top    = -240.0
	bld.offset_right  = -8.0
	bld.offset_bottom =  240.0
	ui.add_child(bld)

	# Панель законов — левый центр
	var laws = load("res://scripts/ui/laws_panel.gd").new()
	laws.name = "LawsPanel"
	laws.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	laws.offset_left   = 8.0
	laws.offset_top    = -185.0
	laws.offset_right  = 235.0
	laws.offset_bottom =  185.0
	ui.add_child(laws)

	# setup() вызывается отложено — узел уже в дереве
	laws.call_deferred("setup", get_meta("laws_manager"))

# ─── Первоначальное состояние ────────────────────────────────────────────────

func _emit_initial_state() -> void:
	EventBus.turn_ended.emit(0)
	EventBus.water_changed.emit(GameState.water, 0.0)
	EventBus.population_changed.emit(GameState.population)
	EventBus.happiness_changed.emit(
		GameState.happiness, GameState.thirst, GameState.discontent)
	EventBus.game_event.emit({
		"turn":        0,
		"title":       "Поселение основано",
		"description": "Вы нашли оазис посреди пустыни. " +
					   "Стройте насосы, следите за запасами воды — " +
					   "пока жара не убила всех.",
		"severity":    0,
	})
