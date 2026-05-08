class_name HexMap
extends Node3D

const HEX_SIZE:   float = 1.10
const MAP_RADIUS: int   = 12

const WATER_RESERVE_MIN: float = 800.0
const WATER_RESERVE_MAX: float = 2000.0

# Диапазоны высоты по типу тайла [min, max]
# Индексы: SAND=0, ROCK=1, OASIS=2, WATER_SOURCE=3, DRY_SOURCE=4, MINE=5
const TILE_HEIGHT_RANGE: Dictionary = {
	0: [0.05, 0.40],   # SAND
	1: [0.55, 1.35],   # ROCK
	2: [0.05, 0.10],   # OASIS
	3: [0.00, 0.15],   # WATER_SOURCE
	4: [0.02, 0.18],   # DRY_SOURCE
	5: [0.45, 1.10],   # MINE
}

var tiles: Dictionary = {}
var _hovered:       Vector2i = Vector2i(-99, -99)
var _selected_tile: Vector2i = Vector2i(-99, -99)
var _camera: Camera3D

var _radius_mi:   MeshInstance3D
var _radius_mat:  StandardMaterial3D
var _place_mi:    MeshInstance3D
var _place_mat:   StandardMaterial3D

# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	_add_ground_plane()
	_generate_map()
	_setup_indicators()
	call_deferred("_init_camera")
	EventBus.building_placed.connect(func(_t, _c): _update_overlay())
	EventBus.assign_workers_request.connect(_on_assign_workers)

func _init_camera() -> void:
	_camera = get_viewport().get_camera_3d()

# ─── Тёмная подложка ─────────────────────────────────────────────────────────

func _add_ground_plane() -> void:
	var plane_mesh      = PlaneMesh.new()
	plane_mesh.size     = Vector2(120.0, 120.0)
	var mi              = MeshInstance3D.new()
	mi.mesh             = plane_mesh
	mi.position         = Vector3(0.0, -0.05, 0.0)
	var mat             = StandardMaterial3D.new()
	mat.albedo_color    = Color(0.06, 0.05, 0.03)
	mat.roughness       = 1.0
	mi.material_override = mat
	add_child(mi)

# ─── Генерация карты ──────────────────────────────────────────────────────────

func _generate_map() -> void:
	var rng    = RandomNumberGenerator.new()
	var rng_wr = RandomNumberGenerator.new()
	rng_wr.randomize()

	for coords: Vector2i in HexGrid.get_hex_in_range(Vector2i.ZERO, MAP_RADIUS):
		var t    = _pick_tile_type(coords, rng)
		var h    = _tile_height(coords, t, rng)
		var tile = HexTile.new()
		var px   = HexGrid.hex_to_pixel(coords.x, coords.y, HEX_SIZE)
		tile.position = Vector3(px.x, 0.0, px.y)
		tile.setup(coords.x, coords.y, HEX_SIZE, t, h)
		add_child(tile)
		tiles[coords]               = tile
		GameState.hex_tiles[coords] = tile

		if t == HexTile.TILE_WATER_SOURCE:
			GameState.tile_water_reserves[coords] = \
				rng_wr.randf_range(WATER_RESERVE_MIN, WATER_RESERVE_MAX)

func _pick_tile_type(coords: Vector2i, rng: RandomNumberGenerator) -> int:
	if coords == Vector2i.ZERO:
		return HexTile.TILE_OASIS
	rng.seed = (coords.x + 300) * 421 + (coords.y + 300) * 173
	var dist  = HexGrid.hex_distance(coords, Vector2i.ZERO)
	var roll  = rng.randf()
	var roll2 = rng.randf()

	# Ближнее кольцо — почти всё вода
	if dist == 1:
		if roll < 0.70: return HexTile.TILE_WATER_SOURCE
		return HexTile.TILE_SAND

	# Второе кольцо — смешанное
	if dist == 2:
		if roll < 0.30: return HexTile.TILE_WATER_SOURCE
		if roll < 0.50: return HexTile.TILE_ROCK
		return HexTile.TILE_SAND

	# Средняя зона (3–5)
	if dist <= 5:
		if roll  < 0.10: return HexTile.TILE_WATER_SOURCE
		if roll  < 0.32: return HexTile.TILE_ROCK
		if roll2 < 0.12: return HexTile.TILE_MINE
		return HexTile.TILE_SAND

	# Внешняя зона (6–8) — много скал
	if roll  < 0.06: return HexTile.TILE_WATER_SOURCE
	if roll  < 0.42: return HexTile.TILE_ROCK
	if roll2 < 0.16: return HexTile.TILE_MINE
	return HexTile.TILE_SAND

func _tile_height(coords: Vector2i, tile_type: int, rng: RandomNumberGenerator) -> float:
	var range_arr: Array = TILE_HEIGHT_RANGE.get(tile_type, [0.0, 0.3])
	# Отдельный сид для высоты, чтобы не влиять на тип тайла
	rng.seed = (coords.x + 500) * 307 + (coords.y + 500) * 241
	return rng.randf_range(range_arr[0], range_arr[1])

# ─── Индикаторы ──────────────────────────────────────────────────────────────

func _setup_indicators() -> void:
	var ring_mesh             = CylinderMesh.new()
	ring_mesh.top_radius      = 1.0
	ring_mesh.bottom_radius   = 1.0
	ring_mesh.height          = 0.04
	ring_mesh.radial_segments = 52
	ring_mesh.rings           = 1
	_radius_mat               = StandardMaterial3D.new()
	_radius_mat.albedo_color  = Color(0.4, 0.9, 0.4, 0.55)
	_radius_mat.transparency  = BaseMaterial3D.TRANSPARENCY_ALPHA
	_radius_mat.shading_mode  = BaseMaterial3D.SHADING_MODE_UNSHADED
	_radius_mi                = MeshInstance3D.new()
	_radius_mi.mesh           = ring_mesh
	_radius_mi.material_override = _radius_mat
	_radius_mi.visible        = false
	add_child(_radius_mi)

	var disc_mesh             = CylinderMesh.new()
	disc_mesh.top_radius      = HEX_SIZE * 0.88
	disc_mesh.bottom_radius   = HEX_SIZE * 0.88
	disc_mesh.height          = 0.04
	disc_mesh.radial_segments = 6
	_place_mat                = StandardMaterial3D.new()
	_place_mat.albedo_color   = Color(0, 1, 0, 0.28)
	_place_mat.transparency   = BaseMaterial3D.TRANSPARENCY_ALPHA
	_place_mat.shading_mode   = BaseMaterial3D.SHADING_MODE_UNSHADED
	_place_mi                 = MeshInstance3D.new()
	_place_mi.mesh            = disc_mesh
	_place_mi.material_override = _place_mat
	_place_mi.visible         = false
	add_child(_place_mi)

# ─── Обновление ховера ───────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	if not _camera:
		return
	var new_hov = _hex_at_mouse()
	if new_hov == _hovered:
		return
	if tiles.has(_hovered):
		tiles[_hovered].set_hover(false)
	_hovered = new_hov
	if tiles.has(_hovered) and GameState.selected_building_type < 0:
		tiles[_hovered].set_hover(true)
	_update_overlay()

func _update_overlay() -> void:
	if not tiles.has(_hovered):
		_place_mi.visible  = false
		_radius_mi.visible = false
		return

	var tile: HexTile = tiles[_hovered]
	var px            = HexGrid.hex_to_pixel(_hovered.x, _hovered.y, HEX_SIZE)
	var tile_h: float = tile.tile_height   # высота верхней грани

	if GameState.selected_building_type >= 0:
		var ok = tile.can_build()
		_place_mi.position       = Vector3(px.x, tile_h + 0.06, px.y)
		_place_mat.albedo_color  = (Color(0.0, 1.0, 0.28, 0.28)
									if ok else Color(1.0, 0.14, 0.04, 0.28))
		_place_mi.visible        = true
		if ok:
			_show_radius(_hovered, _bld_radius(GameState.selected_building_type),
				Color(0.32, 1.0, 0.32, 0.55))
		else:
			_radius_mi.visible = false
	else:
		_place_mi.visible = false
		if tile.building >= 0:
			_show_radius(_hovered, _bld_radius(tile.building),
				Color(0.58, 0.80, 1.0, 0.55))
		else:
			_radius_mi.visible = false

func _show_radius(center: Vector2i, r: int, color: Color) -> void:
	if r <= 0:
		_radius_mi.visible = false
		return
	var cp   = HexGrid.hex_to_pixel(center.x, center.y, HEX_SIZE)
	var px_r = (float(r) + 0.50) * HEX_SIZE * 1.12
	_radius_mi.position      = Vector3(cp.x, 0.10, cp.y)
	_radius_mi.scale         = Vector3(px_r, 1.0, px_r)
	_radius_mat.albedo_color = color
	_radius_mi.visible       = true

# ─── Ввод ────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		if tiles.has(_hovered):
			_handle_click(_hovered)
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		GameState.selected_building_type = -1
		EventBus.building_type_selected.emit(-1)
		_deselect_tile()

func _handle_click(coords: Vector2i) -> void:
	var tile: HexTile = tiles[coords]

	if GameState.selected_building_type >= 0:
		if not tile.can_build():
			return
		if not GameState.can_afford(GameState.selected_building_type):
			EventBus.game_event.emit({
				"turn":        GameState.current_turn,
				"title":       "Нет ресурсов",
				"description": "Недостаточно ресурсов для постройки.",
				"severity":    1,
			})
			return
		GameState.spend_cost(GameState.selected_building_type)
		tile.place_building(GameState.selected_building_type)
		GameState.building_durability[coords] = 100.0
		EventBus.building_placed.emit(GameState.selected_building_type, coords)
		EventBus.resources_changed.emit(GameState.sand, GameState.scrap, GameState.diamonds)
	else:
		if _selected_tile == coords:
			_deselect_tile()
		else:
			_select_tile(coords)

func _select_tile(coords: Vector2i) -> void:
	if tiles.has(_selected_tile):
		tiles[_selected_tile].set_selected(false)
	_selected_tile = coords
	tiles[_selected_tile].set_selected(true)
	EventBus.tile_selected.emit(coords)

func _deselect_tile() -> void:
	if tiles.has(_selected_tile):
		tiles[_selected_tile].set_selected(false)
	_selected_tile = Vector2i(-99, -99)
	EventBus.tile_selected.emit(Vector2i(-99, -99))

# ─── Назначение рабочих ──────────────────────────────────────────────────────

func _on_assign_workers(coords: Vector2i, target: int) -> void:
	var tile: HexTile = tiles.get(coords)
	if not tile:
		return
	var max_w:   int = tile.get_max_workers()
	var current: int = GameState.tile_workers.get(coords, 0)
	var new_count: int
	if target > current:
		var can_add = mini(target - current, GameState.get_available_workers())
		new_count   = current + can_add
	else:
		new_count = target
	new_count = clampi(new_count, 0, max_w)
	if new_count == current:
		return
	GameState.tile_workers[coords] = new_count
	tile.update_workers(new_count)
	EventBus.workers_changed.emit(coords, new_count)

# ─── Raycast: мышь → гекс ────────────────────────────────────────────────────

func _hex_at_mouse() -> Vector2i:
	if not _camera:
		return Vector2i(-99, -99)
	var mouse    = get_viewport().get_mouse_position()
	var ray_from = _camera.project_ray_origin(mouse)
	var ray_dir  = _camera.project_ray_normal(mouse)
	if absf(ray_dir.y) < 0.0005:
		return Vector2i(-99, -99)
	# Пересечение с плоскостью на средней высоте тайлов
	var t   = (0.4 - ray_from.y) / ray_dir.y
	var hit = ray_from + ray_dir * t
	var loc = to_local(hit)
	return HexGrid.pixel_to_hex(Vector2(loc.x, loc.z), HEX_SIZE)

# ─── Радиусы построек ────────────────────────────────────────────────────────

static func _bld_radius(b: int) -> int:
	match b:
		GameState.BUILDING_PUMP:            return 3
		GameState.BUILDING_PURIFIER:        return 2
		GameState.BUILDING_CONDENSER:       return 1
		GameState.BUILDING_CARAVAN_STATION: return 4
		GameState.BUILDING_MINE:            return 0
		_:                                  return 0
