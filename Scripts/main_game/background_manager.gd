extends CanvasLayer
class_name BackgroundManager

## 塔（Tower）背景管理器
## 完全由塔海拔（tower_meter）动态驱动（仿 TETR.IO zenith）。两种表现模式：
##   A. 交叉淡化模式（默认，bg_climb=false）：
##      - 每帧读取 tower_meter，按海拔阈值表（仿 TETR.IO MINIMAL_BGS）选择背景，
##        跨越阈值时交叉淡入淡出（crossfade）。
##      - 塔攀登视差滚动（可开关 bg_scroll）：图像比视口高 30%，随 meter 增加
##        整体向下滚动，量化到 0.5px 减少重排开销。
##   B. 攀登模式（bg_climb=true，可开关）：
##      - 把所有背景图连成一面高墙（22 张按海拔从低到高），随 meter 连续向下
##        滚动，模拟真实爬塔时景色向下掠过；两张图无缝拼接，无交叉淡入。
## 海拔色调叠加（仿 TETR.IO GetAltitudeColor / TINT_GRADIENT_BG_BACK）两种模式
## 都生效：每帧随 meter 连续变化，越高越暗越冷。
## 背景动画总开关（user_setting 的 bg_animation 键）同时控制两种模式的动画。

const BG_PATH_PREFIX: String = "res://Assets/bg/"
const BG_COUNT: int = 22
## 塔海拔上限（对应 FLOOR_HIGHER 最高阈值 11000）
const MAX_METER: float = 11000.0
## 背景图像高度 = 视口高度 × 该倍率（多出的余量用于视差滚动，保证不露边）
const BG_SCROLL_OVERSCAN: float = 1.3

@export var animation_duration: float = 1.5  # 交叉淡入淡出时长（秒）

## 背景下标 → 图片文件名（仿 TETR.IO MINIMAL_BGS 顺序：按海拔从浅到深）
## 22 张 = 10 张基础图 + 12 张同层变体（fa/fb/fc/fd）
const BG_NAMES: Array = [
	"zenith_1",  # 1fa
	"zenith_2",  # 2fa
	"zenith_2b", # 2fb
	"zenith_3",  # 3fa
	"zenith_3b", # 3fb
	"zenith_4",  # 4fa
	"zenith_4b", # 4fb
	"zenith_5",  # 5fa
	"zenith_5b", # 5fb
	"zenith_5c", # 5fc
	"zenith_6",  # 6fa
	"zenith_6b", # 6fb
	"zenith_7",  # 7fa
	"zenith_7b", # 7fb
	"zenith_7c", # 7fc
	"zenith_7d", # 7fd
	"zenith_8",  # 8fa
	"zenith_8b", # 8fb
	"zenith_9",  # 9fa
	"zenith_9b", # 9fb
	"zenith_9c", # 9fc
	"zenith_10", # 10fa
]

## 海拔阈值表：[达到该 meter 时切换到背景下标, 背景下标]
## 仿 TETR.IO MINIMAL_BGS：低层密集（每层 2-3 张变体），高层稀疏。
## 与 FLOOR_HIGHER 楼层边界大致对应，但细化到楼层内的连续推进。
const ALTITUDE_TO_BG: Array = [
	[0,    0],  # zenith_1  (1fa)
	[40,   1],  # zenith_2  (2fa)
	[80,   2],  # zenith_2b (2fb)
	[120,  3],  # zenith_3  (3fa)
	[180,  4],  # zenith_3b (3fb)
	[240,  5],  # zenith_4  (4fa)
	[300,  6],  # zenith_4b (4fb)
	[380,  7],  # zenith_5  (5fa)
	[460,  8],  # zenith_5b (5fb)
	[540,  9],  # zenith_5c (5fc)
	[620,  10], # zenith_6  (6fa)
	[720,  11], # zenith_6b (6fb)
	[820,  12], # zenith_7  (7fa)
	[920,  13], # zenith_7b (7fb)
	[1020, 14], # zenith_7c (7fc)
	[1150, 15], # zenith_7d (7fd)
	[1300, 16], # zenith_8  (8fa)
	[1500, 17], # zenith_8b (8fb)
	[1900, 18], # zenith_9  (9fa)
	[2500, 19], # zenith_9b (9fb)
	[3500, 20], # zenith_9c (9fc)
	[5000, 21], # zenith_10 (10fa)
]

## 攀登模式海拔分段（仿 TETR.IO MINIMAL_BGS 精确高度阈值，与楼层高度表一致）：
## 每个背景下标占据 [CLIMB_BANDS[i], CLIMB_BANDS[i+1]) 高度区间。
## 楼层高度对齐：一层0m→1fa；二层50m→2fa/2fb；三层150m→3fa/3fb；
## 四层300m→4fa/4fb；五层450m→5fa/5fb/5fc；六层650m→6fa/6fb；
## 七层850m→7fa/7fb/7fc/7fd；八层1100m→8fa/8fb；九层1350m→9fa/9fb/9fc；
## 十层1650m→10fa（1650m 以上持续显示最后一张）。
const CLIMB_BANDS: Array = [0, 50, 110, 150, 240, 300, 360, 450, 515, 585, 650, 750, 850, 900, 980, 1030, 1100, 1200, 1350, 1450, 1575, 1650]

var _tower: Node = null
var _current_bg: TextureRect = null
var _next_bg: TextureRect = null
var _tint_rect: ColorRect = null
var _anim_enabled: bool = true
var _scroll_enabled: bool = true
var _climb_enabled: bool = false
var _current_floor: int = 0
var _climb_floor: int = -1
var _scroll_offset: float = 0.0
var _last_vp_size: Vector2 = Vector2.ZERO
var _bg_tween: Tween = null

func _ready() -> void:
	var settings := UserSetting.load_settings()
	_anim_enabled = settings.get("bg_animation", true)
	_scroll_enabled = settings.get("bg_scroll", true)
	_climb_enabled = settings.get("bg_climb", false)
	_tower = get_node_or_null("../TowerController") as Node
	if _tower == null:
		push_warning("BackgroundManager: 未找到 TowerController，背景将不会随海拔变化")
	_setup_layers()
	if _climb_enabled:
		_update_climb(_tower.tower_meter if _tower else 0.0)

## 每帧按塔海拔动态更新背景与色调
func _process(_delta: float) -> void:
	if _tower == null:
		return
	var meter: float = _tower.tower_meter
	if _climb_enabled:
		_update_climb(meter)
	else:
		_update_altitude_bg(meter)
		_update_scroll(meter)
	_update_altitude_tint(meter)

## 按海拔选择背景下标（仿 TETR.IO GetApplicableBg：取最后一个满足阈值的项）
func _altitude_to_bg(meter: float) -> int:
	var idx: int = 0
	for entry: Array in ALTITUDE_TO_BG:
		if meter >= float(entry[0]):
			idx = int(entry[1])
		else:
			break
	return idx

## 海拔背景更新：跨越阈值时交叉淡化
func _update_altitude_bg(meter: float) -> void:
	set_floor(_altitude_to_bg(meter))

## 海拔色调更新：每帧连续变化（仿 TETR.IO GetAltitudeColor，无台阶感）
func _update_altitude_tint(meter: float) -> void:
	var target: Color = _altitude_tint(meter)
	if _tint_rect.color.is_equal_approx(target):
		return
	_tint_rect.color = target

## 创建两个 TextureRect 层用于交叉淡化 + 一个海拔色调叠加层
func _setup_layers() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -10  # 在所有游戏元素之后（最底层）
	add_child(layer)
	_current_bg = _make_texture_rect(layer)
	_next_bg = _make_texture_rect(layer)
	_next_bg.modulate.a = 0.0
	# 海拔色调叠加（置于背景图之上、游戏元素之下）
	_tint_rect = ColorRect.new()
	_tint_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tint_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tint_rect.color = _altitude_tint(0.0)
	layer.add_child(_tint_rect)
	_load_floor(0)
	_layout_bg_layers()

## 创建一个铺满视口的 TextureRect（尺寸/位置由 _layout_bg_layers 手动管理）
func _make_texture_rect(parent: Node) -> TextureRect:
	var tr := TextureRect.new()
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(tr)
	return tr

## 加载指定背景下标（1-22）的背景图
func _load_floor(floor_idx: int) -> void:
	var idx: int = clampi(floor_idx, 0, BG_COUNT - 1)
	var path: String = BG_PATH_PREFIX + str(BG_NAMES[idx]) + ".jpg"
	var tex: Texture2D = load(path)
	if tex:
		_current_bg.texture = tex

## 切换楼层背景（内部由海拔阈值驱动；外部也可手动调用）
func set_floor(floor_idx: int) -> void:
	var idx: int = clampi(floor_idx, 0, BG_COUNT - 1)
	if idx == _current_floor:
		return
	_current_floor = idx
	if not _anim_enabled:
		_load_floor(idx)
		return
	_crossfade_to_floor(idx)

## 交叉淡入淡出到新楼层背景
func _crossfade_to_floor(idx: int) -> void:
	var path: String = BG_PATH_PREFIX + str(BG_NAMES[idx]) + ".jpg"
	var tex: Texture2D = load(path)
	if tex == null:
		return
	# 打断进行中的淡化（防止快速跨越多个阈值时多个 tween 互相冲突）
	if _bg_tween:
		_bg_tween.kill()
		_bg_tween = null
	# 把当前背景内容保留，新图放上层从透明淡入
	_next_bg.texture = tex
	_next_bg.modulate.a = 0.0
	_bg_tween = create_tween()
	_bg_tween.tween_property(_next_bg, "modulate:a", 1.0, animation_duration)
	_bg_tween.tween_callback(func():
		# 淡化完成后交换：新图成为当前，旧层清空
		var old: TextureRect = _current_bg
		_current_bg = _next_bg
		_next_bg = old
		_next_bg.texture = null
		_next_bg.modulate.a = 0.0
	)

## 海拔色调（仿 TETR.IO TINT_GRADIENT_BG_BACK：越高越暗越冷，连续渐变）
func _altitude_tint(meter: float) -> Color:
	var t: float = clampf(meter / MAX_METER, 0.0, 1.0)
	var c1 := Color(1.0, 1.0, 1.0, 0.00)      # 起点：无色调
	var c2 := Color(0.55, 0.65, 0.95, 0.16)   # 中层：淡蓝
	var c3 := Color(0.08, 0.12, 0.32, 0.42)   # 顶部：深蓝暗调
	if t < 0.5:
		return c1.lerp(c2, t * 2.0)
	return c2.lerp(c3, (t - 0.5) * 2.0)

## 切换背景动画开关
func set_anim_enabled(enabled: bool) -> void:
	_anim_enabled = enabled
	var meter: float = _tower.tower_meter if _tower else 0.0
	if _climb_enabled:
		# 攀登模式：立即按当前海拔重绘（动画关闭时 frac 强制为 0，即静止在当前楼层图）
		_climb_floor = -1
		_update_climb(meter)
		_update_altitude_tint(meter)
		return
	if not enabled:
		# 关闭动画时直接显示当前海拔背景
		_current_floor = _altitude_to_bg(meter)
		_load_floor(_current_floor)
		_next_bg.modulate.a = 0.0
		_next_bg.texture = null
		_tint_rect.color = _altitude_tint(meter)

## ========== 塔攀登视差滚动（可开关） ==========

## 随海拔更新滚动偏移：meter 越高图像越往下移（爬塔时景色向下掠过）。
## 偏移量化到 0.5px，避免每帧微小变化触发频繁重排（降低性能开销）。
func _update_scroll(meter: float) -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var size_changed: bool = vp != _last_vp_size
	_last_vp_size = vp
	var max_scroll: float = vp.y * (BG_SCROLL_OVERSCAN - 1.0)
	var target: float = 0.0
	if _scroll_enabled and max_scroll > 0.0:
		target = clampf(meter / MAX_METER, 0.0, 1.0) * max_scroll
	var target_q: float = roundf(target / 0.5) * 0.5
	if size_changed or not is_equal_approx(_scroll_offset, target_q):
		_scroll_offset = target_q
		_layout_bg_layers()

## 布局两张背景层：比视口大（上下各留滚动余量），按当前滚动偏移定位
func _layout_bg_layers() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	if vp.x <= 0.0 or vp.y <= 0.0:
		return
	var w: float = vp.x * 1.02          # 宽度略留余量
	var h: float = vp.y * BG_SCROLL_OVERSCAN
	var pos := Vector2((vp.x - w) * 0.5, -(h - vp.y) * 0.5 + _scroll_offset)
	for tr: TextureRect in [_current_bg, _next_bg]:
		tr.position = pos
		tr.size = Vector2(w, h)

## 切换塔攀登视差滚动
func set_scroll_enabled(enabled: bool) -> void:
	_scroll_enabled = enabled
	_update_scroll(_tower.tower_meter if _tower else 0.0)

## ========== 攀登模式（连续爬塔） ==========

## 给指定背景层设置图片（缓存由 Godot load() 保证，切换廉价）
func _set_texture(rect: TextureRect, idx: int) -> void:
	var i: int = clampi(idx, 0, BG_COUNT - 1)
	var tex: Texture2D = load(BG_PATH_PREFIX + str(BG_NAMES[i]) + ".jpg")
	if tex:
		rect.texture = tex
	rect.modulate.a = 1.0

## 攀登模式：把所有背景连成一面高墙，随 meter 连续向下滚动（爬塔时景色向下掠过）。
## 每张背景占据其对应的真实海拔分段（CLIMB_BANDS，与楼层高度表一致），
## 低层分段窄 → 图像变化快，高层分段宽 → 变化慢，10fa 以上持续显示最后一张。
## 用两张背景层无缝拼接：上层(下一张图)从屏幕顶滑入，下层(当前图)滑出屏幕底。
## 跨越楼层边界时直接切换纹理（因上层的图正是即将成为当前的图，视觉无缝）。
func _update_climb(meter: float) -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	if vp.y <= 0.0:
		return
	# 按海拔分段定位：取最后一个满足 start <= meter 的分段
	var idx: int = 0
	for i in range(CLIMB_BANDS.size() - 1, -1, -1):
		if meter >= float(CLIMB_BANDS[i]):
			idx = i
			break
	var start: float = float(CLIMB_BANDS[idx])
	var end: float = float(CLIMB_BANDS[idx + 1]) if idx < CLIMB_BANDS.size() - 1 else start + float(CLIMB_BANDS[idx] - CLIMB_BANDS[idx - 1])
	var frac: float = 0.0
	if end > start:
		frac = clampf((meter - start) / (end - start), 0.0, 1.0)
	if not _anim_enabled:
		frac = 0.0  # 背景动画关闭 → 停在当前楼层图，不滚动
	if idx != _climb_floor:
		_climb_floor = idx
		_set_texture(_current_bg, idx)
		_set_texture(_next_bg, mini(idx + 1, BG_COUNT - 1))
	# 下层（当前楼层图）：从屏幕顶开始，随 frac 下移
	_current_bg.position = Vector2(0.0, frac * vp.y)
	_current_bg.size = vp
	# 上层（下一楼层图）：在屏幕上方，随 frac 下移进来
	_next_bg.position = Vector2(0.0, (frac - 1.0) * vp.y)
	_next_bg.size = vp

## 切换攀登模式（与交叉淡化模式互斥）
func set_climb_enabled(enabled: bool) -> void:
	_climb_enabled = enabled
	_climb_floor = -1
	var meter: float = _tower.tower_meter if _tower else 0.0
	if enabled:
		_update_climb(meter)
	else:
		# 恢复交叉淡化模式
		_current_floor = _altitude_to_bg(meter)
		_load_floor(_current_floor)
		_next_bg.modulate.a = 0.0
		_next_bg.texture = null
		_update_scroll(meter)
	_update_altitude_tint(meter)
