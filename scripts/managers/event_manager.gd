class_name EventManager
extends Node

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _sandstorm_turns: int = 0

const CHANCE_SANDSTORM  = 0.07
const CHANCE_SOURCE_DRY = 0.04
const CHANCE_CARAVAN    = 0.11
const CHANCE_MARAUDER   = 0.05
const CHANCE_SURVIVORS  = 0.13
const GRACE_PERIOD      = 3    # первые N ходов без случайных событий

func _ready() -> void:
	_rng.randomize()

func process_turn() -> void:
	_tick_sandstorm()
	if GameState.current_turn <= GRACE_PERIOD:
		return
	_roll_sandstorm()
	_roll_source_dry()
	_roll_caravan()
	_roll_marauder()
	_roll_survivors()

# ─────────────────────────────────────────────────────────────────────────────

func _tick_sandstorm() -> void:
	if _sandstorm_turns <= 0:
		return
	_sandstorm_turns -= 1
	if _sandstorm_turns == 0:
		GameState.sandstorm_active = false
		_log("Буря утихла", "Небо прояснилось. Производство воды восстановлено.", 1)

func _roll_sandstorm() -> void:
	if _sandstorm_turns > 0 or _rng.randf() >= CHANCE_SANDSTORM:
		return
	_sandstorm_turns = _rng.randi_range(2, 5)
	GameState.sandstorm_active = true
	var penalty = _rng.randf_range(0.35, 0.60)
	# Штраф к уже вычисленному производству этого хода
	GameState.water_production *= (1.0 - penalty)
	GameState.water_net = GameState.water_production - GameState.water_consumption
	GameState.water = maxf(0.0, GameState.water + GameState.water_net)
	EventBus.water_changed.emit(GameState.water, GameState.water_net)
	_log("⛈  Песчаная буря!",
		"Буря накрыла оазис! Производство снижено на %d%% на %d дней." % [
			int(penalty * 100.0), _sandstorm_turns], 2)

func _roll_source_dry() -> void:
	if _rng.randf() >= CHANCE_SOURCE_DRY:
		return
	var sources: Array = []
	for coords: Vector2i in GameState.hex_tiles:
		if GameState.hex_tiles[coords].tile_type == HexTile.TILE_WATER_SOURCE:
			sources.append(coords)
	if sources.is_empty():
		return
	var target: Vector2i = sources[_rng.randi() % sources.size()]
	GameState.hex_tiles[target].set_tile_type(HexTile.TILE_DRY_SOURCE)
	_log("Источник иссяк!",
		"Подземный пласт воды истощился. Насосы в этом районе потеряли мощность.", 2)

func _roll_caravan() -> void:
	if not _has_caravan_station() or _rng.randf() >= CHANCE_CARAVAN:
		return
	var gain = float(_rng.randi_range(30, 90))
	GameState.water += gain
	EventBus.water_changed.emit(GameState.water, GameState.water_net)
	_log("🐪  Торговый караван!",
		"Торговцы доставили %.0f единиц воды в обмен на припасы." % gain, 0)

func _roll_marauder() -> void:
	if not _has_caravan_station() or _rng.randf() >= CHANCE_MARAUDER:
		return
	var stolen = minf(GameState.water * 0.20, 60.0)
	GameState.water = maxf(0.0, GameState.water - stolen)
	EventBus.water_changed.emit(GameState.water, GameState.water_net)
	_log("⚔  Мародёры атакуют!",
		"Банда налётчиков захватила торговый пост и похитила %.0f ед. воды." % stolen, 2)

func _roll_survivors() -> void:
	if GameState.survivors_waiting > 0 or _rng.randf() >= CHANCE_SURVIVORS:
		return
	var count = _rng.randi_range(3, 18)
	GameState.survivors_waiting = count
	EventBus.survivor_arrived.emit(count)
	_log("👤  Выжившие у ворот",
		"%d человек добрались до оазиса. Принять их в поселение?" % count, 1)

func _has_caravan_station() -> bool:
	for coords: Vector2i in GameState.hex_tiles:
		if GameState.hex_tiles[coords].building == GameState.BUILDING_CARAVAN_STATION:
			return true
	return false

func _log(title: String, desc: String, sev: int) -> void:
	EventBus.game_event.emit({
		"turn": GameState.current_turn, "title": title,
		"description": desc, "severity": sev,
	})
