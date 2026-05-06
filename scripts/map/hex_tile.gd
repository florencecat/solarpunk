class_name HexTile
extends Node3D

## Типы тайлов
const TILE_SAND         = 0
const TILE_ROCK         = 1
const TILE_OASIS        = 2
const TILE_WATER_SOURCE = 3
const TILE_DRY_SOURCE   = 4
const TILE_MINE         = 5

## Толщина (глубина) каждого типа тайла
const TILE_DEPTH = {
	0: 0.40,  # SAND
	1: 0.80,  # ROCK  — заметно выше
	2: 0.22,  # OASIS — утоплен
	3: 0.38,  # WATER_SOURCE
	4: 0.25,  # DRY_SOURCE
	5: 0.90,  # TILE_MINE
}

var coords:    Vector2i = Vector2i.ZERO
var tile_type: int      = TILE_SAND
var building:  int      = -1        # -1 = нет постройки
var hex_size:  float    = 1.1

var _tile_mi:    MeshInstance3D     # основная призма тайла
var _outline_mi: MeshInstance3D     # подсветка при ховере / выборе
var _bld_root:   Node3D             # контейнер постройки
var _worker_lbl: Label3D            # отображение рабочих

var _is_hovered:  bool = false
var _is_selected: bool = false

# ─────────────────────────────────────────────────────────────────────────────

func setup(q: int, r: int, size: float, t: int) -> void:
	coords    = Vector2i(q, r)
	hex_size  = size
	tile_type = t
	_build_visuals()

func _build_visuals() -> void:
	var depth: float = TILE_DEPTH.get(tile_type, 0.4)

	# ── Основная призма ──────────────────────────────────────────────────────
	_tile_mi          = MeshInstance3D.new()
	_tile_mi.mesh     = _hex_prism(hex_size * 0.95, depth)
	_tile_mi.position = Vector3(0.0, -depth * 0.5, 0.0)   # верх = y=0
	var mat           = StandardMaterial3D.new()
	mat.albedo_color  = _tile_color(tile_type)
	mat.roughness     = 0.88
	_tile_mi.material_override = mat
	add_child(_tile_mi)

	# ── Тонкий диск-подсветка (hover / select) ───────────────────────────────
	_outline_mi          = MeshInstance3D.new()
	_outline_mi.mesh     = _hex_prism(hex_size * 1.03, 0.055)
	_outline_mi.position = Vector3(0.0, 0.03, 0.0)         # чуть выше поверхности
	var omat             = StandardMaterial3D.new()
	omat.albedo_color    = Color(1, 1, 1, 0.75)
	omat.emission_enabled = true
	omat.emission         = Color(0.35, 0.35, 0.35)
	omat.transparency     = BaseMaterial3D.TRANSPARENCY_ALPHA
	omat.shading_mode     = BaseMaterial3D.SHADING_MODE_UNSHADED
	_outline_mi.material_override = omat
	_outline_mi.visible = false
	add_child(_outline_mi)

	# ── Декоративные детали по типу тайла ────────────────────────────────────
	match tile_type:
		TILE_OASIS:        _add_oasis_water()
		TILE_WATER_SOURCE: _add_water_bubble()
		TILE_ROCK:         _add_rock_detail()
		TILE_MINE:         _add_mine_detail()

func _add_oasis_water() -> void:
	var water     = MeshInstance3D.new()
	water.mesh    = _hex_prism(hex_size * 0.60, 0.06)
	water.position = Vector3(0.0, 0.04, 0.0)
	var wm        = StandardMaterial3D.new()
	wm.albedo_color = Color(0.25, 0.70, 0.95, 0.80)
	wm.roughness    = 0.05
	wm.metallic     = 0.15
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.material_override = wm
	add_child(water)

func _add_water_bubble() -> void:
	var s        = SphereMesh.new()
	s.radius     = hex_size * 0.16
	s.height     = hex_size * 0.32
	var mi       = MeshInstance3D.new()
	mi.mesh      = s
	mi.position  = Vector3(0.0, 0.22, 0.0)
	var m        = StandardMaterial3D.new()
	m.albedo_color = Color(0.28, 0.52, 0.92, 0.72)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = m
	add_child(mi)

func _add_rock_detail() -> void:
	var offsets = [Vector3(0.2, 0.0, 0.1), Vector3(-0.18, 0.0, 0.22), Vector3(0.05, 0.0, -0.28)]
	for o in offsets:
		var bm     = BoxMesh.new()
		bm.size    = Vector3(0.18, 0.22, 0.18)
		var mi     = MeshInstance3D.new()
		mi.mesh    = bm
		mi.position = o + Vector3(0.0, 0.11, 0.0)
		mi.rotation_degrees = Vector3(0, randf_range(0, 45), 0)
		var m      = StandardMaterial3D.new()
		m.albedo_color = Color(0.42, 0.36, 0.26)
		m.roughness    = 0.95
		mi.material_override = m
		add_child(mi)

func _add_mine_detail() -> void:
	# Тёмный вход в шахту
	var shaft_mesh   = BoxMesh.new()
	shaft_mesh.size  = Vector3(0.32, 0.36, 0.32)
	var shaft        = MeshInstance3D.new()
	shaft.mesh       = shaft_mesh
	shaft.position   = Vector3(0.0, 0.18, 0.0)
	var sm           = StandardMaterial3D.new()
	sm.albedo_color  = Color(0.16, 0.12, 0.08)
	sm.roughness     = 0.95
	shaft.material_override = sm
	add_child(shaft)
	# Рудные жилы
	for op in [Vector3(0.28, 0.06, 0.10), Vector3(-0.22, 0.06, 0.20)]:
		var ore_mesh   = BoxMesh.new()
		ore_mesh.size  = Vector3(0.13, 0.10, 0.10)
		var ore_mi     = MeshInstance3D.new()
		ore_mi.mesh    = ore_mesh
		ore_mi.position = op
		var om         = StandardMaterial3D.new()
		om.albedo_color = Color(0.38, 0.32, 0.18)
		om.metallic     = 0.55
		om.roughness    = 0.40
		ore_mi.material_override = om
		add_child(ore_mi)

# ─── API ─────────────────────────────────────────────────────────────────────

func set_hover(h: bool) -> void:
	_is_hovered = h
	_refresh_outline()

func set_selected(s: bool) -> void:
	_is_selected = s
	_refresh_outline()

func _refresh_outline() -> void:
	if _is_selected:
		_outline_mi.visible = true
		var m = _outline_mi.material_override as StandardMaterial3D
		m.albedo_color = Color(0.0, 1.0, 0.45, 0.80)
		m.emission     = Color(0.0, 0.55, 0.25)
	elif _is_hovered:
		_outline_mi.visible = true
		var m = _outline_mi.material_override as StandardMaterial3D
		m.albedo_color = Color(1.0, 1.0, 1.0, 0.70)
		m.emission     = Color(0.30, 0.30, 0.30)
	else:
		_outline_mi.visible = false

func place_building(b: int) -> void:
	if _bld_root:
		_bld_root.queue_free()
	building  = b
	_bld_root = _make_building(b)
	add_child(_bld_root)

func remove_building() -> void:
	if _bld_root:
		_bld_root.queue_free()
		_bld_root = null
	building = -1

func can_build() -> bool:
	if building >= 0:
		return false
	match tile_type:
		TILE_OASIS, TILE_ROCK, TILE_MINE:
			return false
	# Нельзя строить, если рабочие уже добывают здесь
	if GameState.tile_workers.get(coords, 0) > 0:
		return false
	# Шахта — только на песке
	if GameState.selected_building_type == GameState.BUILDING_MINE:
		return tile_type == TILE_SAND
	return true

func set_tile_type(t: int) -> void:
	tile_type = t
	if _tile_mi:
		(_tile_mi.material_override as StandardMaterial3D).albedo_color = _tile_color(t)

## Обновить отображение рабочих (Label3D-билборд над тайлом)
func update_workers(count: int) -> void:
	if not _worker_lbl:
		_worker_lbl              = Label3D.new()
		_worker_lbl.billboard    = BaseMaterial3D.BILLBOARD_ENABLED
		_worker_lbl.font_size    = 32
		_worker_lbl.outline_size = 8
		_worker_lbl.pixel_size   = 0.010
		_worker_lbl.position     = Vector3(0.0, 0.70, 0.0)
		_worker_lbl.modulate     = Color(1.0, 0.90, 0.45)
		add_child(_worker_lbl)
	_worker_lbl.visible = (count > 0)
	if count > 0:
		_worker_lbl.text = "w%d" % count

## Максимальное число рабочих на тайле (зависит от постройки / типа тайла)
func get_max_workers() -> int:
	match building:
		GameState.BUILDING_PUMP:            return 5
		GameState.BUILDING_PURIFIER:        return 7
		GameState.BUILDING_CONDENSER:       return 5
		GameState.BUILDING_CARAVAN_STATION: return 2
		GameState.BUILDING_MINE:            return 4
	match tile_type:
		TILE_MINE: return 4
		TILE_SAND: return 2
	return 0

# ─── Постройки ────────────────────────────────────────────────────────────────

static func _make_building(b: int) -> Node3D:
	var root = Node3D.new()
	match b:
		GameState.BUILDING_PUMP:            _build_pump(root)
		GameState.BUILDING_PURIFIER:        _build_purifier(root)
		GameState.BUILDING_CONDENSER:       _build_condenser(root)
		GameState.BUILDING_CARAVAN_STATION: _build_caravan(root)
		GameState.BUILDING_MINE:            _build_mine(root)
	return root

static func _build_pump(root: Node3D) -> void:
	# Корпус
	var body_mesh    = BoxMesh.new()
	body_mesh.size   = Vector3(0.52, 1.0, 0.52)
	var body         = _mi(body_mesh, Color(0.12, 0.40, 0.95))
	body.position    = Vector3(0.0, 0.50, 0.0)
	root.add_child(body)
	# Купол сверху
	var cap_mesh     = SphereMesh.new()
	cap_mesh.radius  = 0.24
	cap_mesh.height  = 0.48
	var cap          = _mi(cap_mesh, Color(0.45, 0.72, 1.0))
	cap.position     = Vector3(0.0, 1.24, 0.0)
	root.add_child(cap)
	# Труба сбоку
	var pipe_mesh    = CylinderMesh.new()
	pipe_mesh.top_radius    = 0.055
	pipe_mesh.bottom_radius = 0.055
	pipe_mesh.height        = 0.40
	pipe_mesh.radial_segments = 8
	var pipe         = _mi(pipe_mesh, Color(0.08, 0.28, 0.70))
	pipe.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	pipe.position    = Vector3(0.38, 0.68, 0.0)
	root.add_child(pipe)

static func _build_purifier(root: Node3D) -> void:
	# Бак
	var tank_mesh                = CylinderMesh.new()
	tank_mesh.top_radius         = 0.40
	tank_mesh.bottom_radius      = 0.44
	tank_mesh.height             = 0.85
	tank_mesh.radial_segments    = 12
	var tank         = _mi(tank_mesh, Color(0.08, 0.78, 0.58))
	tank.position    = Vector3(0.0, 0.425, 0.0)
	root.add_child(tank)
	# Фильтр сверху
	var flt_mesh                 = CylinderMesh.new()
	flt_mesh.top_radius          = 0.20
	flt_mesh.bottom_radius       = 0.24
	flt_mesh.height              = 0.28
	flt_mesh.radial_segments     = 8
	var flt          = _mi(flt_mesh, Color(0.55, 0.90, 0.72))
	flt.position     = Vector3(0.0, 1.0, 0.0)
	root.add_child(flt)

static func _build_condenser(root: Node3D) -> void:
	# Основание
	var base_mesh   = BoxMesh.new()
	base_mesh.size  = Vector3(0.80, 0.32, 0.80)
	var base        = _mi(base_mesh, Color(0.58, 0.58, 0.78))
	base.position   = Vector3(0.0, 0.16, 0.0)
	root.add_child(base)
	# Пластины-рёбра
	for i in range(5):
		var fin_mesh   = BoxMesh.new()
		fin_mesh.size  = Vector3(0.07, 0.38, 0.72)
		var fin        = _mi(fin_mesh, Color(0.72, 0.72, 0.92))
		fin.position   = Vector3(-0.30 + i * 0.15, 0.51, 0.0)
		root.add_child(fin)

static func _build_caravan(root: Node3D) -> void:
	# Платформа
	var plat_mesh   = BoxMesh.new()
	plat_mesh.size  = Vector3(1.0, 0.52, 0.88)
	var plat        = _mi(plat_mesh, Color(0.95, 0.50, 0.08))
	plat.position   = Vector3(0.0, 0.26, 0.0)
	root.add_child(plat)
	# Флагшток
	var pole_mesh                = CylinderMesh.new()
	pole_mesh.top_radius         = 0.035
	pole_mesh.bottom_radius      = 0.035
	pole_mesh.height             = 0.90
	pole_mesh.radial_segments    = 6
	var pole        = _mi(pole_mesh, Color(0.55, 0.38, 0.18))
	pole.position   = Vector3(0.38, 0.97, 0.30)
	root.add_child(pole)
	# Флаг
	var flag_mesh   = BoxMesh.new()
	flag_mesh.size  = Vector3(0.32, 0.18, 0.04)
	var flag        = _mi(flag_mesh, Color(0.95, 0.25, 0.15))
	flag.position   = Vector3(0.38 + 0.16, 1.33, 0.30)
	root.add_child(flag)

static func _build_mine(root: Node3D) -> void:
	# Основание — бетонный воротник
	var base_mesh  = BoxMesh.new()
	base_mesh.size = Vector3(0.55, 0.18, 0.55)
	var base       = _mi(base_mesh, Color(0.32, 0.28, 0.22))
	base.position  = Vector3(0.0, 0.09, 0.0)
	root.add_child(base)
	# Деревянные опоры (А-образные)
	for side in [-1, 1]:
		var beam_mesh  = BoxMesh.new()
		beam_mesh.size = Vector3(0.08, 0.82, 0.08)
		var beam       = _mi(beam_mesh, Color(0.52, 0.36, 0.16))
		beam.position  = Vector3(side * 0.26, 0.41, 0.0)
		beam.rotation_degrees = Vector3(0.0, 0.0, side * -16.0)
		root.add_child(beam)
	# Перекладина
	var cross_mesh  = BoxMesh.new()
	cross_mesh.size = Vector3(0.70, 0.09, 0.10)
	var cross       = _mi(cross_mesh, Color(0.42, 0.28, 0.12))
	cross.position  = Vector3(0.0, 0.80, 0.0)
	root.add_child(cross)
	# Подъёмное колесо
	var wheel_mesh              = CylinderMesh.new()
	wheel_mesh.top_radius       = 0.19
	wheel_mesh.bottom_radius    = 0.19
	wheel_mesh.height           = 0.06
	wheel_mesh.radial_segments  = 10
	var wheel       = _mi(wheel_mesh, Color(0.32, 0.24, 0.14))
	wheel.position  = Vector3(0.0, 0.90, 0.0)
	wheel.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	root.add_child(wheel)

## Вспомогательный MeshInstance3D с StandardMaterial3D
static func _mi(mesh: Mesh, color: Color) -> MeshInstance3D:
	var mi   = MeshInstance3D.new()
	mi.mesh  = mesh
	var mat  = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness    = 0.65
	mi.material_override = mat
	return mi

# ─── Геометрия хекс-призмы ───────────────────────────────────────────────────

## Создаёт ArrayMesh: верхняя грань при y=0, нижняя при y=-depth.
static func _hex_prism(size: float, depth: float) -> ArrayMesh:
	var pts = HexGrid.get_hex_points(size)   # 6 точек, Vector2
	var half = depth * 0.5

	var verts   = PackedVector3Array()
	var norms   = PackedVector3Array()
	var indices = PackedInt32Array()

	# ── Верхняя грань (нормаль +Y, обход CCW сверху) ─────────────────────────
	var t0 = 0
	verts.append(Vector3(0.0, half, 0.0))
	norms.append(Vector3.UP)
	for p in pts:
		verts.append(Vector3(p.x, half, p.y))
		norms.append(Vector3.UP)
	for i in range(6):
		indices.append(t0)
		indices.append(t0 + i + 1)
		indices.append(t0 + (i + 1) % 6 + 1)

	# ── Нижняя грань (нормаль -Y, обход CW сверху = CCW снизу) ──────────────
	var b0 = verts.size()
	verts.append(Vector3(0.0, -half, 0.0))
	norms.append(Vector3.DOWN)
	for p in pts:
		verts.append(Vector3(p.x, -half, p.y))
		norms.append(Vector3.DOWN)
	for i in range(6):
		indices.append(b0)
		indices.append(b0 + (i + 1) % 6 + 1)
		indices.append(b0 + i + 1)

	# ── Боковые грани ─────────────────────────────────────────────────────────
	# Godot/Vulkan использует CW-обмотку для лицевых граней (снаружи).
	# Порядок: A,C,B и A,D,C — CW со стороны внешней нормали.
	for i in range(6):
		var j  = (i + 1) % 6
		var p0 = pts[i]
		var p1 = pts[j]
		var n  = Vector3((p0.x + p1.x) * 0.5, 0.0, (p0.y + p1.y) * 0.5).normalized()
		var s  = verts.size()
		verts.append(Vector3(p0.x,  half, p0.y))   # A: верх, текущий
		verts.append(Vector3(p1.x,  half, p1.y))   # B: верх, следующий
		verts.append(Vector3(p1.x, -half, p1.y))   # C: низ, следующий
		verts.append(Vector3(p0.x, -half, p0.y))   # D: низ, текущий
		for _k in range(4): norms.append(n)
		indices.append(s); indices.append(s + 2); indices.append(s + 1)
		indices.append(s); indices.append(s + 3); indices.append(s + 2)

	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_INDEX]  = indices

	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

# ─── Цвета ───────────────────────────────────────────────────────────────────

static func _tile_color(t: int) -> Color:
	match t:
		TILE_SAND:         return Color(0.82, 0.65, 0.25)
		TILE_ROCK:         return Color(0.48, 0.40, 0.28)
		TILE_OASIS:        return Color(0.20, 0.54, 0.76)
		TILE_WATER_SOURCE: return Color(0.16, 0.44, 0.72)
		TILE_DRY_SOURCE:   return Color(0.40, 0.24, 0.14)
		TILE_MINE:         return Color(0.28, 0.22, 0.16)
		_:                 return Color(0.70, 0.55, 0.20)
