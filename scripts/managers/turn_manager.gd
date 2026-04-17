class_name TurnManager
extends Node

var _resource_mgr:   ResourceManager
var _population_mgr: PopulationManager
var _event_mgr:      EventManager

var _auto_timer: float = 0.0

func setup(rm: ResourceManager, pm: PopulationManager, em: EventManager) -> void:
	_resource_mgr   = rm
	_population_mgr = pm
	_event_mgr      = em

func _process(delta: float) -> void:
	if not GameState.auto_turn:
		return
	_auto_timer += delta
	if _auto_timer >= GameState.auto_turn_interval:
		_auto_timer = 0.0
		advance_turn()

func advance_turn() -> void:
	GameState.current_turn += 1
	EventBus.turn_started.emit(GameState.current_turn)

	_resource_mgr.process_turn()    # 1. ресурсы (производство → потребление → запас)
	_population_mgr.process_turn()  # 2. настроение (жажда → недовольство → бунт)
	_event_mgr.process_turn()       # 3. случайные события

	EventBus.turn_ended.emit(GameState.current_turn)
