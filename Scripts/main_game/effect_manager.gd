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

## 碎片列表
var _shards: Array = []
## 圆环列表
var _rings: Array = []

## B2B 蓄力徽章（六边形旋转，仿 TETR.IO b2b counter 元素）
var _b2b_badge_active: bool = false
var _b2b_badge_pos: Vector2 = Vector2.ZERO
var _b2b_badge_charge: int = 0          # 当前 BTB 计数（btb_count）
var _b2b_badge_charge_at: int = 4       # 蓄满阈值
var _b2b_badge_angle: float = 0.0       # 当前旋转角
var _b2b_badge_tick: float = 0.0        # 蓄满后 ticking 圆环间隔计时
var _b2b_badge_cell: float = 24.0       # 当前格子大小（用于缩放）

const GRAVITY: float = 420.0
const MAX_SHARDS: int = 300

## B2B 蓄力颜色渐变（蓝→绿→黄→红→紫→白，仿 TETR.IO B2B_COLOR_GRADIENT）
const B2B_COLOR_STOPS: Array = [
	[0.00, Color(0.30, 0.60, 1.00)],  # 蓝
	[0.20, Color(0.00, 1.00, 0.60)],  # 绿
	[0.40, Color(1.00, 1.00, 0.00)],  # 黄
	[0.60, Color(1.00, 0.30, 0.25)],  # 红
	[0.80, Color(0.60, 0.20, 1.00)],  # 紫
	[1.00, Color(1.00, 1.00, 1.00)],  # 白
]


func _process(delta: float) -> void:
	if _shards.is_empty() and _rings.is_empty() and not _b2b_badge_active:
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
	# B2B 徽章：旋转 + 蓄满后周期释放 ticking 圆环
	if _b2b_badge_active:
		# 蓄力越高转得越快（仿 TETR.IO progress: angle += e * clamp(1..4, 1+0.1*charge)）
		var speed: float = maxf(1.0, minf(4.0, 1.0 + 0.1 * float(_b2b_badge_charge)))
		_b2b_badge_angle += dt * speed
		if _b2b_badge_charge >= _b2b_badge_charge_at:
			_b2b_badge_tick += dt
			var interval: float = maxf(0.12, 0.32 - 0.02 * float(_b2b_badge_charge))
			if _b2b_badge_tick >= interval:
				_b2b_badge_tick = 0.0
				spawn_ring(_b2b_badge_pos, _get_b2b_color(_b2b_badge_charge), _b2b_badge_cell * 1.7, 0.4)
	# 清理
	_shards = _shards.filter(func(s): return s.life > 0.0)
	_rings = _rings.filter(func(r): return r.life > 0.0)
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


## ========== B2B 蓄力徽章 ==========

## 更新/开启 B2B 蓄力徽章（pos 为徽章中心世界坐标，charge 为当前 btb_count）
func set_b2b_badge(pos: Vector2, charge: int, charge_at: int, cell: float):
	_b2b_badge_active = true
	_b2b_badge_pos = pos
	_b2b_badge_charge = charge
	_b2b_badge_charge_at = maxi(1, charge_at)
	_b2b_badge_cell = maxf(cell, 4.0)
	queue_redraw()

## 关闭/移除 B2B 蓄力徽章
func clear_b2b_badge():
	_b2b_badge_active = false
	_b2b_badge_tick = 0.0
	queue_redraw()

## 蓄力颜色（按 charge 超阈值后的增量映射到渐变色带）
## 从蓄满阈值(charge_at)到最高档(24)缓慢过渡，避免颜色跳变过快：
## t 从 0（到达阈值时）线性增长到 1（charge=24 时）
func _get_b2b_color(charge: int) -> Color:
	var amount: float = maxf(0.0, float(charge) - float(_b2b_badge_charge_at))
	var t: float = clampf(amount / 20.0, 0.0, 1.0)
	for i in range(B2B_COLOR_STOPS.size() - 1):
		var t0: float = B2B_COLOR_STOPS[i][0]
		var t1: float = B2B_COLOR_STOPS[i + 1][0]
		if t >= t0 and t <= t1:
			var f: float = 1.0
			if t1 > t0:
				f = (t - t0) / (t1 - t0)
			return (B2B_COLOR_STOPS[i][1] as Color).lerp(B2B_COLOR_STOPS[i + 1][1] as Color, f)
	return B2B_COLOR_STOPS[-1][1] as Color

## 六边形顶点（尖角朝上，start_angle 为整体旋转角）
func _hexagon_points(center: Vector2, radius: float, start_angle: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(6):
		var a: float = start_angle + float(i) * TAU / 6.0
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	return pts

func _draw_b2b_badge():
	var charge := _b2b_badge_charge
	var charged: bool = charge >= _b2b_badge_charge_at
	var color := _get_b2b_color(charge)
	# 蓄力越高徽章越大（仿 TETR.IO scale r 随 charge 增长）
	var r: float = clampf((float(charge) - float(_b2b_badge_charge_at) + 1.0) / 6.0, 0.0, 1.0)
	var radius: float = _b2b_badge_cell * (0.65 + 0.35 * r)
	var alpha: float = 1.0 if charged else 0.45
	# 六边形填充（半透明）+ 描边
	var pts := _hexagon_points(_b2b_badge_pos, radius, _b2b_badge_angle + PI / 2.0)
	var fill := color
	fill.a = alpha * 0.35
	var outline := color
	outline.a = alpha
	draw_colored_polygon(pts, fill)
	var closed := pts
	closed.append(pts[0])
	draw_polyline(closed, outline, 2.0, true)
	# 中心蓄力数字
	var num := str(maxi(1, charge - _b2b_badge_charge_at + 1))
	var font := ThemeDB.fallback_font
	var fs := maxi(6, roundi(_b2b_badge_cell * (0.75 + 0.25 * r)))
	var ts := font.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var text_pos: Vector2 = _b2b_badge_pos - ts * 0.5 + Vector2(0, ts.y * 0.35)
	var text_color := color
	text_color.a = alpha
	draw_string(font, text_pos + Vector2(1, 1), num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.BLACK)
	draw_string(font, text_pos, num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, text_color)


## 清空全部特效
func clear_all():
	_shards.clear()
	_rings.clear()
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
	# B2B 蓄力徽章
	if _b2b_badge_active:
		_draw_b2b_badge()
