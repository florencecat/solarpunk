class_name TurnManager
extends Node

var _resource_mgr:  ResourceManager
var _population_mgr: PopulationManager
var _worker_mgr:    WorkerManager
var _event_mgr:     EventManager
var _research_mgr:  ResearchManager
var _act_mgr:       ActManager

var _auto_timer: float = 0.0

func setup(rm: ResourceManager, pm: PopulationManager,
		   wm: WorkerManager,   em: EventManager,
		   rsm: ResearchManager, am: ActManager) -> void:
	_resource_mgr   = rm
	_population_mgr = pm
	_worker_mgr     = wm
	_event_mgr      = em
	_research_mgr   = rsm
	_act_mgr        = am

func _process(delta: float) -> void:
	if not GameState.auto_turn:
		return
	_auto_timer += delta
	if _auto_timer >= GameState.auto_turn_interval:
		_auto_timer = 0.0
		advance_turn()

func advance_turn() -> void:
	if GameState.is_game_over or GameState.is_victory:
		return
	if GameState.pending_choice:
		return

	GameState.current_turn += 1
	EventBus.turn_started.emit(GameState.current_turn)

	_resource_mgr.process_turn()    # 1. вода (производство → потребление → запас)
	_population_mgr.process_turn()  # 2. население (жажда → недовольство → бунт → рост)
	_worker_mgr.process_turn()      # 3. добыча ресурсов рабочими
	_event_mgr.process_turn()       # 4. случайные события
	_research_mgr.process_turn()    # 5. прогресс исследований
	_act_mgr.process_turn()         # 6. акты → мегапроекты → победа

	EventBus.turn_ended.emit(GameState.current_turn)
