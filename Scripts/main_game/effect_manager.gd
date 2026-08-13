extends Node2D
class_name EffectManager

## 特效管理器
## 供消行/攻击/BTB等场景使用，负责：
##   - 碎片粒子（消行方块飞溅、BTB释放爆裂）
##   - 冲击波圆环（伤害数字/大攻击的扩散环）
##   - 攻击数字弹出（大号数字 pop + 上浮淡出）
## 所有特效都在世界坐标下绘制（与版面坐标一致）。

class Shard:
	var pos: Vector2
	var vel: Vector2
	var color: Color
	var size: float
	var life: float
	var max_life: float

class Ring:
	var pos: Vector2
	var radius: float
	var max_radius: float
	var color: Color
	var life: float
	var max_life: float

## B2B 蓄力 ticking 火花（小圆点，带阻尼飘散，仿 TETR.IO b2bcharge_ticking）
class Spark:
	var pos: Vector2
	var vel: Vector2
	var color: Color
	var size: float
	var life: float
	var max_life: float

## 碎片列表
var _shards: Array = []
## 圆环列表
var _rings: Array = []
## ticking 火花列表
var _sparks: Array = []

## B2B 蓄力徽章（六边形旋转，仿 TETR.IO b2b counter 元素）
var _b2b_badge_active: bool = false
var _b2b_badge_pos: Vector2 = Vector2.ZERO
var _b2b_badge_charge: int = 0          # 当前 BTB 计数（btb_count）
var _b2b_badge_charge_at: int = 4       # 蓄满阈值
var _b2b_badge_base: int = 0            # 蓄力基准（TETR.IO b2bcharge_base，本地为 0）
var _b2b_badge_angle: float = 0.0       # 当前旋转角
var _b2b_badge_tick: float = 0.0        # 蓄满后 ticking 火花发射间隔计时
var _b2b_badge_cell: float = 24.0       # 当前格子大小（用于缩放）
var _b2b_pop_timer: float = -1.0        # 蓄力增长 pop 动画计时（-1 = 未播放）
var _b2b_spring_timer: float = -1.0     # 越过蓄满阈值 spring-in 动画计时
var _b2b_break_timer: float = -1.0      # 断开爆炸动画计时（-1 = 未播放）

const GRAVITY: float = 420.0
const MAX_SHARDS: int = 300
const MAX_SPARKS: int = 60

# ---- B2B 蓄力颜色（仿 TETR.IO B2B_COLOR_GRADIENT，按绝对 BTB 计数取色）----
## 未达到蓄满阈值时徽章/文本的暗淡色（TETR.IO 0xFFDDE4）
const B2B_DIM_COLOR: Color = Color(1.0, 0.867, 0.894)
## 颜色分段：[起始btb, 结束btb, 起始色, 结束色]
const B2B_COLOR_GRADIENT: Array = [
	[0, 4, Color(0.00, 0.60, 1.00), Color(0.00, 1.00, 0.80)],    # 蓝→青
	[4, 8, Color(0.00, 1.00, 0.80), Color(0.00, 1.00, 0.00)],    # 青→绿
	[8, 12, Color(0.00, 1.00, 0.00), Color(1.00, 1.00, 0.00)],   # 绿→黄
	[12, 30, Color(1.00, 1.00, 0.00), Color(1.00, 0.00, 0.00)],  # 黄→红
	[30, 60, Color(1.00, 0.00, 0.00), Color(1.00, 0.00, 1.00)],  # 红→品红
	[60, 100, Color(1.00, 0.00, 1.00), Color(0.00, 0.57, 1.00)], # 品红→亮蓝
	[100, 150, Color(0.00, 0.57, 1.00), Color(0.58, 1.00, 0.89)], # 亮蓝→浅青
	[150, 250, Color(0.58, 1.00, 0.89), Color(1.00, 0.82, 0.53)], # 浅青→橙
	[250, 999999, Color(1.00, 0.82, 0.53), Color(1.00, 1.00, 1.00)], # 橙→白
]


func _process(delta: float) -> void:
	if _shards.is_empty() and _rings.is_empty() and _sparks.is_empty() and not _b2b_badge_active:
		return
	var dt := delta
	# 碎片：带重力，逐渐淡出
	for s: Shard in _shards:
		s.life -= dt
		s.vel.y += GRAVITY * dt
		s.pos += s.vel * dt
	# 圆环：扩散
	for r: Ring in _rings:
		r.life -= dt
		var t: float = 1.0
		if r.max_life > 0.0:
			t = clampf(1.0 - r.life / r.max_life, 0.0, 1.0)
		r.radius = 2.0 + (r.max_radius - 2.0) * _ease_out_cubic(t)
	# ticking 火花：带阻尼缓慢飘散
	for sp: Spark in _sparks:
		sp.life -= dt
		sp.pos += sp.vel * dt
		sp.vel *= maxf(0.0, 1.0 - 4.0 * dt)
	# B2B 徽章：旋转 + 蓄满后持续发射 ticking 火花（仿 TETR.IO progress()）
	if _b2b_badge_active:
		# 蓄力越高转得越快（TETR.IO：angle += e * clamp(1..4, 1+0.1*(charge-at+1))）
		var speed: float = maxf(1.0, minf(4.0, 1.0 + 0.1 * (float(_b2b_badge_charge) - float(_b2b_badge_charge_at) + 1.0)))
		_b2b_badge_angle += dt * speed
		# 蓄力增长 pop 动画（0.15s）
		if _b2b_pop_timer >= 0.0:
			_b2b_pop_timer += dt
			if _b2b_pop_timer >= 0.15:
				_b2b_pop_timer = -1.0
		# 越过阈值 spring-in 动画（0.25s）
		if _b2b_spring_timer >= 0.0:
			_b2b_spring_timer += dt
			if _b2b_spring_timer >= 0.25:
				_b2b_spring_timer = -1.0
		# 断开爆炸动画（0.8s），结束后关闭徽章
		if _b2b_break_timer >= 0.0:
			_b2b_break_timer += dt
			if _b2b_break_timer >= 0.8:
				_b2b_break_timer = -1.0
				clear_b2b_badge()
		# 蓄满后持续 ticking 火花（爆炸期间暂停发射）
		elif _b2b_badge_charge >= _b2b_badge_charge_at:
			_b2b_badge_tick += dt
			var power: float = clampf((float(_b2b_badge_charge) - float(_b2b_badge_charge_at) + 1.0) / 30.0, 0.0, 1.0)
			var interval: float = lerpf(0.05, 0.012, power)
			if _b2b_badge_tick >= interval:
				_b2b_badge_tick = 0.0
				var count: int = 1 + int(power * 2.0)
				for _i in range(count):
					_spawn_spark(_get_b2b_center(), _get_b2b_color(_b2b_badge_charge))
	# 清理
	_shards = _shards.filter(func(s): return s.life > 0.0)
	_rings = _rings.filter(func(r): return r.life > 0.0)
	_sparks = _sparks.filter(func(sp): return sp.life > 0.0)
	queue_redraw()


## 碎片爆发：pos 世界坐标，color 颜色，count 数量，speed 初速
func spawn_shards(pos: Vector2, color: Color, count: int = 8, speed: float = 220.0):
	if _shards.size() >= MAX_SHARDS:
		return
	var rng := RandomManager.get_random("MISC")
	count = mini(count, MAX_SHARDS - _shards.size())
	for i in range(count):
		var s := Shard.new()
		s.pos = pos + Vector2(rng.randf_range(-3, 3), rng.randf_range(-3, 3))
		var ang := rng.randf_range(0.0, TAU)
		var spd := rng.randf_range(speed * 0.4, speed)
		s.vel = Vector2(cos(ang), sin(ang)) * spd + Vector2(0, -speed * 0.25)
		s.color = color
		s.size = rng.randf_range(2.5, 5.5)
		s.max_life = rng.randf_range(0.45, 0.8)
		s.life = s.max_life
		_shards.append(s)
	queue_redraw()


## 冲击波圆环
func spawn_ring(pos: Vector2, color: Color, max_radius: float = 80.0, duration: float = 0.45):
	var r := Ring.new()
	r.pos = pos
	r.radius = 2.0
	r.max_radius = max_radius
	r.color = color
	r.max_life = duration
	r.life = duration
	_rings.append(r)
	queue_redraw()


## B2B ticking 火花：徽章中心小圆点，带阻尼飘散（仿 TETR.IO b2bcharge_ticking）
func _spawn_spark(pos: Vector2, color: Color):
	if _sparks.size() >= MAX_SPARKS:
		return
	var rng := RandomManager.get_random("MISC")
	var sp := Spark.new()
	sp.pos = pos + Vector2(rng.randf_range(-2, 2), rng.randf_range(-2, 2))
	var ang := rng.randf_range(0.0, TAU)
	var spd := rng.randf_range(4.0, 26.0)
	sp.vel = Vector2(cos(ang), sin(ang)) * spd
	sp.color = color
	sp.size = rng.randf_range(1.2, 2.6)
	sp.max_life = rng.randf_range(0.2, 0.4)
	sp.life = sp.max_life
	_sparks.append(sp)
	queue_redraw()


## ========== B2B 蓄力徽章 ==========

## 更新/开启 B2B 蓄力徽章（pos 为徽章中心世界坐标，charge 为当前 btb_count）
## charge_base 为蓄力基准（TETR.IO b2bcharge_base，本地固定 0）
func set_b2b_badge(pos: Vector2, charge: int, charge_at: int, cell: float, charge_base: int = 0):
	var was_active: bool = _b2b_badge_active
	var prev_charge: int = _b2b_badge_charge
	var prev_charge_at: int = _b2b_badge_charge_at
	_b2b_badge_active = true
	_b2b_badge_pos = pos
	_b2b_badge_charge = charge
	_b2b_badge_charge_at = maxi(1, charge_at)
	_b2b_badge_base = maxi(0, charge_base)
	_b2b_badge_cell = maxf(cell, 4.0)
	# 断开爆炸未播完时被新的蓄力打断 → 恢复正常徽章
	_b2b_break_timer = -1.0
	# 越过蓄满阈值 → spring-in（TETR.IO up_charged）
	if not was_active or prev_charge < prev_charge_at:
		if charge >= _b2b_badge_charge_at:
			_b2b_spring_timer = 0.0
	# 蓄力持续增长 → pop（TETR.IO up 的 1→1.2→1 / 1→1.4→1）
	elif charge > prev_charge and charge >= _b2b_badge_charge_at:
		_b2b_pop_timer = 0.0
	queue_redraw()

## 关闭/移除 B2B 蓄力徽章
func clear_b2b_badge():
	_b2b_badge_active = false
	_b2b_badge_tick = 0.0
	_b2b_pop_timer = -1.0
	_b2b_spring_timer = -1.0
	_b2b_break_timer = -1.0
	queue_redraw()

## BTB 断开（蓄满后）：徽章爆炸动画 + 数字爆裂（仿 TETR.IO down_send）
## 0.5s 内徽章 1→1.6→0，0.8s 内数字 1→4→0，并带白字 "B2B X0" 闪烁
func break_b2b_badge(_amount: int):
	if not _b2b_badge_active:
		return
	_b2b_break_timer = 0.0
	queue_redraw()

## 蓄力颜色（仿 TETR.IO B2B_COLOR_GRADIENT，按绝对 BTB 计数取色插值）
## 未达蓄满阈值返回暗淡色 B2B_DIM_COLOR
func _get_b2b_color(charge: int) -> Color:
	return _get_b2b_color_at(charge, _b2b_badge_charge_at)

## 公开的蓄力颜色查询（供伤害数字着色）：charge 为绝对 BTB 计数
func get_b2b_color(charge: int, charge_at: int) -> Color:
	return _get_b2b_color_at(charge, charge_at)

func _get_b2b_color_at(charge: int, charge_at: int) -> Color:
	if charge < charge_at:
		return B2B_DIM_COLOR
	for stop: Array in B2B_COLOR_GRADIENT:
		if charge >= stop[0] and charge < stop[1]:
			var f: float = float(charge - stop[0]) / float(stop[1] - stop[0])
			return (stop[2] as Color).lerp(stop[3] as Color, f)
	return B2B_COLOR_GRADIENT[-1][3] as Color

## 蓄力缩放因子 l（仿 TETR.IO：(charge-at+1)/6），限制 1..1.6，避免徽章过大
func _get_b2b_scale() -> float:
	return clampf((float(_b2b_badge_charge) - float(_b2b_badge_charge_at) + 1.0) / 6.0, 1.0, 1.6)

## 徽章当前半径（不包含动画缩放）
func _get_b2b_radius() -> float:
	return _b2b_badge_cell * 0.6 * _get_b2b_scale()

## 徽章中心：以 _b2b_badge_pos 为右边缘锚点，徽章向左生长，绝不遮挡右侧 B2B 文本
func _get_b2b_center() -> Vector2:
	return _b2b_badge_pos - Vector2(_get_b2b_radius(), 0.0)

## 断开爆炸：徽章缩放曲线（0.5s 内 1→1.6→0）
func _break_badge_scale(bt: float) -> float:
	if bt < 0.5:
		return lerpf(1.0, 1.6, _ease_out_quad(bt / 0.5))
	return lerpf(1.6, 0.0, (bt - 0.5) / 0.3)

## 断开爆炸：数字缩放曲线（0.8s 内 1→4→0）
func _break_num_scale(bt: float) -> float:
	if bt < 0.4:
		return lerpf(1.0, 4.0, _ease_out_quad(bt / 0.4))
	return lerpf(4.0, 0.0, (bt - 0.4) / 0.4)

## 断开爆炸："B2B X0" 白字闪烁透明度（仿 TETR.IO down_send 文字闪烁）
func _break_flicker_alpha(bt: float) -> float:
	if bt >= 0.7:
		return lerpf(1.0, 0.0, (bt - 0.7) / 0.1)
	var on: bool = int(bt / 0.1) % 2 == 0
	return 1.0 if on else 0.0

func _ease_out_quad(t: float) -> float:
	var u: float = clampf(t, 0.0, 1.0)
	return 1.0 - (1.0 - u) * (1.0 - u)

## 六边形顶点（尖角朝上，start_angle 为整体旋转角）
func _hexagon_points(center: Vector2, radius: float, start_angle: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(6):
		var a: float = start_angle + float(i) * TAU / 6.0
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	return pts

func _draw_b2b_badge():
	var charge := _b2b_badge_charge
	var color := _get_b2b_color(charge)
	# 徽章半径（上限约 1 格），以 _b2b_badge_pos 为右边缘锚点向左生长
	var radius: float = _get_b2b_radius()
	var center: Vector2 = _get_b2b_center()
	# 动画组合缩放
	var badge_mult: float = 1.0
	var num_mult: float = 1.0
	if _b2b_break_timer >= 0.0:
		# 断开爆炸：徽章 1→1.6→0，数字 1→4→0，白字闪烁
		var bt: float = _b2b_break_timer
		badge_mult = _break_badge_scale(bt)
		num_mult = _break_num_scale(bt)
		radius *= badge_mult
		color = Color.WHITE
	elif _b2b_spring_timer >= 0.0:
		# 越过阈值 spring-in：0→1.4→1（0.25s）
		var s: float = clampf(_b2b_spring_timer / 0.25, 0.0, 1.0)
		if s < 0.5:
			badge_mult = lerpf(0.0, 1.4, _ease_out_quad(s / 0.5))
			num_mult = lerpf(0.0, 1.6, _ease_out_quad(s / 0.5))
		else:
			badge_mult = lerpf(1.4, 1.0, (s - 0.5) / 0.5)
			num_mult = lerpf(1.6, 1.0, (s - 0.5) / 0.5)
		radius *= badge_mult
	elif _b2b_pop_timer >= 0.0:
		# 蓄力增长 pop：徽章 1→1.2→1，数字 1→1.4→1（0.15s）
		var p: float = clampf(_b2b_pop_timer / 0.15, 0.0, 1.0)
		badge_mult = 1.0 + 0.2 * sin(p * PI)
		num_mult = 1.0 + 0.4 * sin(p * PI)
		radius *= badge_mult
	# 蓄满但未接近满档时半透明（TETR.IO：charge < at+7-base 时 α=0.3）
	var alpha: float = 1.0
	if not _b2b_break_timer >= 0.0 and charge < _b2b_badge_charge_at + 7 - _b2b_badge_base:
		alpha = 0.3
	# 六边形填充（半透明）+ 描边
	var pts := _hexagon_points(center, radius, _b2b_badge_angle + PI / 2.0)
	var fill := color
	fill.a = alpha * 0.35
	var outline := color
	outline.a = alpha
	draw_colored_polygon(pts, fill)
	var closed := pts
	closed.append(pts[0])
	draw_polyline(closed, outline, 2.0, true)
	# 中心蓄力数字（TETR.IO：charge - at + 1 + base）
	var num := str(maxi(1, charge - _b2b_badge_charge_at + 1 + _b2b_badge_base))
	var font := ThemeDB.fallback_font
	var fs := maxi(6, roundi(_b2b_badge_cell * 0.8 * _get_b2b_scale() * num_mult))
	var ts := font.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var text_pos: Vector2 = center - ts * 0.5 + Vector2(0, ts.y * 0.35)
	var text_color := color
	text_color.a = alpha
	draw_string(font, text_pos + Vector2(1, 1), num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.BLACK)
	draw_string(font, text_pos, num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, text_color)
	# 断开爆炸：白字 "B2B X0" 闪烁（仿 TETR.IO down_send 文字闪烁）
	if _b2b_break_timer >= 0.0:
		var bt: float = _b2b_break_timer
		var flick_alpha: float = _break_flicker_alpha(bt)
		var flash_text: String = "B2B X0"
		var fs2: int = maxi(8, roundi(_b2b_badge_cell * 0.9))
		var ts2 := font.get_string_size(flash_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2)
		var flash_pos: Vector2 = center - ts2 * 0.5 + Vector2(0, -_b2b_badge_cell * 1.1)
		var fc := Color.WHITE
		fc.a = flick_alpha
		draw_string(font, flash_pos + Vector2(1, 1), flash_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, Color.BLACK)
		draw_string(font, flash_pos, flash_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, fc)


## 清空全部特效
func clear_all():
	_shards.clear()
	_rings.clear()
	_sparks.clear()
	clear_b2b_badge()
	queue_redraw()


func _ease_out_cubic(t: float) -> float:
	var u: float = t - 1.0
	return 1.0 + u * u * u


func _draw() -> void:
	# 碎片
	for s: Shard in _shards:
		var alpha: float = clampf(s.life / s.max_life, 0.0, 1.0)
		var c := s.color
		c.a = alpha
		var half: float = s.size * 0.5
		draw_rect(Rect2(s.pos.x - half, s.pos.y - half, s.size, s.size), c, true)
	# 圆环
	for r: Ring in _rings:
		var alpha: float = clampf(r.life / r.max_life, 0.0, 1.0)
		var c := r.color
		c.a = alpha * 0.8
		var width: float = 2.0 + 2.0 * (1.0 - alpha)
		draw_arc(r.pos, r.radius, 0.0, TAU, 40, c, width, true)
	# ticking 火花（软圆点，随生命缩小淡出）
	for sp: Spark in _sparks:
		var alpha: float = clampf(sp.life / sp.max_life, 0.0, 1.0)
		var c := sp.color
		c.a = alpha * 0.8
		draw_circle(sp.pos, sp.size * (0.4 + 0.6 * alpha), c)
	# B2B 蓄力徽章
	if _b2b_badge_active:
		_draw_b2b_badge()
