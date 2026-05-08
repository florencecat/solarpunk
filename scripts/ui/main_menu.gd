## Главное меню — Вариант Б: схематичный эмблемный.
## Тёмный фон + сетка колец + центральная hex-эмблема + заголовок + кнопки.
extends Control

signal new_game
signal quit_game

# ─── Цвета (SP palette) ──────────────────────────────────────────────────────
const C_INK      := Color(0.055, 0.039, 0.024)
const C_BG       := Color(0.082, 0.067, 0.039)
const C_PANEL    := Color(0.110, 0.090, 0.063)
const C_STROKE   := Color(0.227, 0.184, 0.125)
const C_STROKEHI := Color(0.353, 0.290, 0.188)
const C_SAND     := Color(0.831, 0.710, 0.463)
const C_BONE     := Color(0.922, 0.863, 0.714)
const C_TEXT     := Color(0.847, 0.784, 0.620)
const C_MUTED    := Color(0.541, 0.478, 0.361)
const C_TSAND    := Color(0.788, 0.659, 0.416)
const C_TSANDDK  := Color(0.643, 0.533, 0.318)
const C_TOASIS   := Color(0.227, 0.545, 0.416)
const C_WATER    := Color(0.353, 0.643, 0.812)

# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)
	_build_ui()
	call_deferred("queue_redraw")

# ─── Построение UI ───────────────────────────────────────────────────────────

func _build_ui() -> void:
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 0)
	add_child(vbox)

	# Пространство над заголовком
	var top_spc = Control.new()
	top_spc.custom_minimum_size = Vector2(0, 88)
	vbox.add_child(top_spc)

	# Заголовок СОЛЯРПАНК
	var title_lbl = Label.new()
	title_lbl.text = "СОЛЯРПАНК"
	var tls = LabelSettings.new()
	tls.font_size    = 72
	# tls.letter_spacing = 6.0
	tls.font_color   = C_BONE
	title_lbl.label_settings = tls
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_lbl)

	# Подзаголовок О · А · З · И · С
	var sub_lbl = Label.new()
	sub_lbl.text = "О  ·  А  ·  З  ·  И  ·  С"
	var sls = LabelSettings.new()
	sls.font_size    = 20
	# sls.letter_spacing = 10.0
	sls.font_color   = C_SAND
	sub_lbl.label_settings = sls
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sub_lbl)

	# Растягивающийся разделитель
	var flex = Control.new()
	flex.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(flex)

	# Строка кнопок (центрирована)
	var btn_center = CenterContainer.new()
	btn_center.custom_minimum_size = Vector2(0, 90)
	vbox.add_child(btn_center)

	var btn_wrap = PanelContainer.new()
	var bps = StyleBoxFlat.new()
	bps.bg_color = Color(C_PANEL.r, C_PANEL.g, C_PANEL.b, 0.92)
	for prop in ["border_width_left","border_width_right","border_width_top","border_width_bottom"]:
		bps.set(prop, 1)
	bps.border_color = C_STROKE
	btn_wrap.add_theme_stylebox_override("panel", bps)
	btn_center.add_child(btn_wrap)

	var btn_hbox = HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 0)
	btn_wrap.add_child(btn_hbox)

	var ng = _make_btn("НОВАЯ ИГРА", true)
	ng.pressed.connect(func(): new_game.emit())
	btn_hbox.add_child(ng)

	# Вертикальный разделитель
	var sep = Panel.new()
	sep.custom_minimum_size = Vector2(1, 0)
	var ss = StyleBoxFlat.new(); ss.bg_color = C_STROKE
	sep.add_theme_stylebox_override("panel", ss)
	btn_hbox.add_child(sep)

	var qb = _make_btn("ВЫХОД", false)
	qb.pressed.connect(func(): quit_game.emit())
	btn_hbox.add_child(qb)

	# Нижний отступ
	var bot_spc = Control.new()
	bot_spc.custom_minimum_size = Vector2(0, 60)
	vbox.add_child(bot_spc)

func _make_btn(label: String, primary: bool) -> Button:
	var btn = Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(220, 0)
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_color_override("font_color",
		C_SAND if primary else C_TEXT)
	btn.add_theme_color_override("font_hover_color", C_BONE)
	btn.add_theme_color_override("font_pressed_color", C_BONE)

	var s = StyleBoxFlat.new()
	s.bg_color = Color(0, 0, 0, 0)
	s.content_margin_left  = 36.0; s.content_margin_right  = 36.0
	s.content_margin_top   = 22.0; s.content_margin_bottom = 22.0
	btn.add_theme_stylebox_override("normal", s)

	var sh = s.duplicate()
	(sh as StyleBoxFlat).bg_color = Color(C_SAND.r * 0.12, C_SAND.g * 0.12, C_SAND.b * 0.12, 1.0)
	btn.add_theme_stylebox_override("hover", sh)

	var sp = s.duplicate()
	(sp as StyleBoxFlat).bg_color = Color(C_SAND.r * 0.22, C_SAND.g * 0.22, C_SAND.b * 0.22, 1.0)
	btn.add_theme_stylebox_override("pressed", sp)

	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return btn

# ─── Кастомная отрисовка ─────────────────────────────────────────────────────

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 2.0 or h < 2.0:
		return
	var cx := w * 0.5
	var cy := h * 0.5

	# Фон
	draw_rect(Rect2(0, 0, w, h), C_INK)

	# Тонкое центральное свечение (имитация radial-gradient)
	for i in range(6, 0, -1):
		var t  := float(i) / 6.0
		var r  := minf(w, h) * 0.65 * t
		var al := 0.07 * (1.0 - t)
		draw_circle(Vector2(cx, cy + 30.0), r,
			Color(C_PANEL.r, C_PANEL.g, C_PANEL.b, al))

	# Сетка колец
	var gc := Color(C_SAND.r, C_SAND.g, C_SAND.b, 0.10)
	for r in [80.0, 160.0, 260.0, 380.0]:
		draw_arc(Vector2(cx, cy + 30.0), r, 0, TAU, 72, gc, 0.5)
	draw_line(Vector2(0, cy + 30.0), Vector2(w, cy + 30.0), gc, 0.4)
	draw_line(Vector2(cx, 0),        Vector2(cx, h),        gc, 0.4)

	# Hex-эмблема (центр чуть выше середины экрана)
	var ex := cx
	var ey := cy - 30.0

	_draw_hex(ex, ey, 140.0, Color(0, 0, 0, 0),
		Color(C_SAND.r, C_SAND.g, C_SAND.b, 0.30), 1.0)
	_draw_hex(ex, ey, 120.0, C_PANEL, C_STROKEHI, 1.2)
	_draw_hex(ex, ey,  86.0, Color(0, 0, 0, 0),
		Color(C_SAND.r, C_SAND.g, C_SAND.b, 0.22), 0.8)

	# 6 окружающих мини-гексов
	for i in range(6):
		var ang := deg_to_rad(60.0 * float(i) - 30.0)
		var mx  := ex + cos(ang) * 60.0
		var my  := ey + sin(ang) * 60.0
		var fill := C_TSAND if i % 2 == 0 else C_TSANDDK
		_draw_hex(mx, my, 28.0, fill, C_INK, 0.6)

	# Центральный оазисный гекс + вода + точка
	_draw_hex(ex, ey, 28.0, C_TOASIS, C_INK, 0.6)
	draw_circle(Vector2(ex, ey), 12.0, C_WATER)
	draw_circle(Vector2(ex, ey),  5.0, Color(C_BONE.r, C_BONE.g, C_BONE.b, 0.9))

	# Засечки по углам внешнего кольца
	for i in range(6):
		var ang := deg_to_rad(60.0 * float(i) - 90.0)
		var p1  := Vector2(ex + cos(ang) * 148.0, ey + sin(ang) * 148.0)
		var p2  := Vector2(ex + cos(ang) * 166.0, ey + sin(ang) * 166.0)
		draw_line(p1, p2, C_SAND, 1.2)

# ─── Вспомогательные ─────────────────────────────────────────────────────────

func _draw_hex(cx: float, cy: float, radius: float,
			   fill: Color, stroke: Color, stroke_w: float) -> void:
	var pts := PackedVector2Array()
	for i in range(6):
		var ang := deg_to_rad(60.0 * float(i) - 30.0)
		pts.append(Vector2(cx + radius * cos(ang), cy + radius * sin(ang)))
	if fill.a > 0.01:
		draw_colored_polygon(pts, fill)
	if stroke.a > 0.01 and stroke_w > 0.0:
		for i in range(6):
			draw_line(pts[i], pts[(i + 1) % 6], stroke, stroke_w)
