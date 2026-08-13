extends Node2D
class_name BoosterGauge

## 塔楼层推进器（Booster）仪表
## 位于版面正下方，外观为胶囊形推进器（仿 TETR.IO HUD 元素）：
##   - 外层描边框架 + 内部深色轨道
##   - 轨道中央的填充条 = 当前楼层到下一楼层的推进进度（tower_meter）
##   - 10 段刻度（仿 TETR.IO bar_segmented 分段表），填充随进度逐段点亮
##   - 中央显示当前楼层数
## 数据源：TowerController（tower_meter / current_stage / FLOOR_HIGHER）

@export var tower_controller: TowerController
@export var board_drawer: TetrisBoardDrawer

@export var width_cells: float = 12.0        # 推进器宽度（格子数）
@export var height_cells: float = 1.1        # 推进器高度（格子数）
@export var below_gap_cells: float = 0.6     # 距版面底部间隔（格子数）
@export var segment_count: int = 10          # 刻度段数

# 颜色
@export var frame_color: Color = Color(1, 1, 1, 0.35)          # 框架描边
@export var track_color: Color = Color(0.08, 0.10, 0.16, 0.85) # 轨道底色
@export var tick_color: Color = Color(1, 1, 1, 0.22)           # 未点亮刻度
@export var label_color: Color = Color(1, 1, 1, 0.85)          # 楼层数字
@export var label_outline_color: Color = Color(0, 0, 0, 0.9)   # 楼层数字描边

var _floor_count: int = 0
var _progress: float = 0.0
var _stage: int = 0
var _last_progress: float = -1.0
var _last_stage: int = -1

func _ready() -> void:
	if tower_controller == null:
		tower_controller = get_node_or_null("../../TowerController") as TowerController
	if board_drawer == null:
		board_drawer = get_node_or_null("../MainBoard/TetrisBoardDrawer") as TetrisBoardDrawer
	_floor_count = TowerController.FLOOR_HIGHER.size()
	if tower_controller:
		_stage = tower_controller.current_stage
		_update_progress()

func _process(_delta: float) -> void:
	if tower_controller == null:
		return
	_update_progress()
	if _progress != _last_progress or _stage != _last_stage:
		_last_progress = _progress
		_last_stage = _stage
		queue_redraw()

## 计算当前楼层推进进度（0..1），最高楼层恒为 1.0
func _update_progress() -> void:
	var higher: Array = TowerController.FLOOR_HIGHER
	_stage = tower_controller.current_stage
	var meter: float = tower_controller.tower_meter
	var low: float = float(higher[clampi(_stage, 0, _floor_count - 1)])
	var high: float = 1e12
	if _stage < _floor_count - 1:
		high = float(higher[_stage + 1])
	if meter <= low or high <= low:
		_progress = 0.0
	elif meter >= high:
		_progress = 1.0
	else:
		_progress = clampf((meter - low) / (high - low), 0.0, 1.0)

## 推进器填充颜色：低层青 → 中层黄 → 高层红紫
func _fill_color() -> Color:
	if _floor_count <= 1:
		return Color(0.25, 0.75, 1.0)
	var t: float = float(_stage) / float(_floor_count - 1)
	var c1 := Color(0.25, 0.75, 1.0)
	var c2 := Color(1.0, 0.85, 0.25)
	var c3 := Color(1.0, 0.25, 0.45)
	if t < 0.5:
		return c1.lerp(c2, t * 2.0)
	return c2.lerp(c3, (t - 0.5) * 2.0)

func _make_pill_style(fill: Color, border: Color, border_w: int, radius: float) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(int(radius))
	return sb

func _draw() -> void:
	if board_drawer == null:
		return
	var cell: float = board_drawer.cell_size
	var w: float = width_cells * cell
	var h: float = height_cells * cell
	var cx: float = board_drawer.offset_x + board_drawer.grid_width * cell * 0.5
	var bottom: float = board_drawer.offset_y + board_drawer.grid_height * cell
	var rect := Rect2(Vector2(cx - w * 0.5, bottom + below_gap_cells * cell), Vector2(w, h))
	var radius: float = h * 0.5

	# 轨道
	draw_style_box(_make_pill_style(track_color, Color(0, 0, 0, 0), 0, radius), rect)
	# 填充（仪表在推进器中央）
	var fill: Color = _fill_color()
	fill.a = 0.85
	if _progress > 0.0:
		var fw: float = maxf(h, w * _progress)
		var fill_rect := Rect2(rect.position, Vector2(fw, h))
		draw_style_box(_make_pill_style(fill, Color(0, 0, 0, 0), 0, radius), fill_rect)
	# 刻度（10 段，随进度点亮）
	if segment_count > 1:
		for i in range(segment_count):
			var frac: float = float(i) / float(segment_count - 1)
			var x: float = rect.position.x + rect.size.x * frac
			var lit: bool = _progress >= frac
			var c := fill if lit else tick_color
			draw_line(Vector2(x, rect.position.y + h * 0.22), Vector2(x, rect.position.y + h * 0.78), c, 1.0)
	# 框架描边
	draw_style_box(_make_pill_style(Color(0, 0, 0, 0), frame_color, 2, radius), rect)
	# 中央楼层数字
	var label_text: String = "MAX" if _stage >= _floor_count - 1 and _progress >= 1.0 else "FLOOR %d" % (_stage + 1)
	var font: Font = ThemeDB.fallback_font
	var fs: int = maxi(6, roundi(cell * 0.55))
	var ts := font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var text_pos: Vector2 = rect.position + Vector2((rect.size.x - ts.x) * 0.5, (rect.size.y - ts.y) * 0.5)
	draw_string(font, text_pos + Vector2(1, 1), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, label_outline_color)
	draw_string(font, text_pos, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, label_color)
