class_name HexGrid

## Утилиты для flat-top шестиугольной сетки в осевых координатах (q, r).

const SQRT3: float = 1.7320508075688772935

# 6 соседних направлений (axial)
const DIRECTIONS = [
	Vector2i( 1,  0), Vector2i( 1, -1), Vector2i( 0, -1),
	Vector2i(-1,  0), Vector2i(-1,  1), Vector2i( 0,  1),
]

## Осевые координаты → позиция в пикселях (flat-top)
static func hex_to_pixel(q: int, r: int, size: float) -> Vector2:
	return Vector2(
		size * 1.5 * float(q),
		size * (SQRT3 * 0.5 * float(q) + SQRT3 * float(r))
	)

## Позиция в пикселях → ближайший гекс
static func pixel_to_hex(pos: Vector2, size: float) -> Vector2i:
	var q = (2.0 / 3.0) * pos.x / size
	var r = (-1.0 / 3.0 * pos.x + SQRT3 / 3.0 * pos.y) / size
	return axial_round(q, r)

## Округление дробных осевых координат до целых
static func axial_round(q: float, r: float) -> Vector2i:
	var s  = -q - r
	var rq = roundi(q)
	var rr = roundi(r)
	var rs = roundi(s)
	var dq = absf(float(rq) - q)
	var dr = absf(float(rr) - r)
	var ds = absf(float(rs) - s)
	if dq > dr and dq > ds:
		rq = -rr - rs
	elif dr > ds:
		rr = -rq - rs
	return Vector2i(rq, rr)

## Расстояние между двумя гексами
static func hex_distance(a: Vector2i, b: Vector2i) -> int:
	var d = a - b
	return (absi(d.x) + absi(d.y) + absi(d.x + d.y)) / 2

## Все соседи координаты
static func get_neighbors(coords: Vector2i) -> Array:
	var out: Array = []
	for d in DIRECTIONS:
		out.append(coords + d)
	return out

## Все гексы в радиусе radius от center
static func get_hex_in_range(center: Vector2i, radius: int) -> Array:
	var out: Array = []
	for q in range(-radius, radius + 1):
		var r1 = maxi(-radius, -q - radius)
		var r2 = mini( radius, -q + radius)
		for r in range(r1, r2 + 1):
			out.append(center + Vector2i(q, r))
	return out

## Кольцо гексов на расстоянии radius от center
static func get_ring(center: Vector2i, radius: int) -> Array:
	if radius == 0:
		return [center]
	var out: Array = []
	var cur = center + DIRECTIONS[4] * radius
	for i in range(6):
		for _j in range(radius):
			out.append(cur)
			cur = cur + DIRECTIONS[i]
	return out

## 6 вершин flat-top шестиугольника радиусом size
static func get_hex_points(size: float) -> PackedVector2Array:
	var pts = PackedVector2Array()
	for i in range(6):
		var a = deg_to_rad(60.0 * float(i))   # flat-top: первая вершина вправо
		pts.append(Vector2(size * cos(a), size * sin(a)))
	return pts
