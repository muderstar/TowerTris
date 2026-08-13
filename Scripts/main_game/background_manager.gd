extends CanvasLayer
class_name BackgroundManager

## 塔（Tower）背景管理器
## 根据楼层（stage）切换对应的背景图，楼层变化时做交叉淡入淡出（crossfade）动画。
## 背景动画可开关（user_setting 的 bg_animation 键）。

const BG_PATH_PREFIX: String = "res://Assets/bg/zenith_"
const BG_COUNT: int = 10

@export var animation_duration: float = 1.5  # 交叉淡入淡出时长（秒）

var _current_bg: TextureRect = null
var _next_bg: TextureRect = null
var _anim_enabled: bool = true
var _current_floor: int = 0

func _ready() -> void:
	_anim_enabled = UserSetting.load_settings().get("bg_animation", true)
	_setup_layers()

## 创建两个 TextureRect 层用于交叉淡化
func _setup_layers() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -10  # 在所有游戏元素之后（最底层）
	add_child(layer)
	_current_bg = _make_texture_rect(layer)
	_next_bg = _make_texture_rect(layer)
	_next_bg.modulate.a = 0.0
	_load_floor(0)

## 创建一个铺满全屏的 TextureRect
func _make_texture_rect(parent: Node) -> TextureRect:
	var tr := TextureRect.new()
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(tr)
	return tr

## 加载指定楼层（1-10）的背景图
func _load_floor(floor_idx: int) -> void:
	var idx: int = clampi(floor_idx, 0, BG_COUNT - 1)
	var path: String = BG_PATH_PREFIX + str(idx + 1) + ".jpg"
	var tex: Texture2D = load(path)
	if tex:
		_current_bg.texture = tex

## 切换楼层（由 tower_controller.stage_changed 连接调用）
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
	var path: String = BG_PATH_PREFIX + str(idx + 1) + ".jpg"
	var tex: Texture2D = load(path)
	if tex == null:
		return
	# 把当前背景内容保留，新图放上层从透明淡入
	_next_bg.texture = tex
	_next_bg.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_next_bg, "modulate:a", 1.0, animation_duration)
	tween.tween_callback(func():
		# 淡化完成后交换：新图成为当前，旧层清空
		var old: TextureRect = _current_bg
		_current_bg = _next_bg
		_next_bg = old
		_next_bg.texture = null
		_next_bg.modulate.a = 0.0
	)

## 切换背景动画开关
func set_anim_enabled(enabled: bool) -> void:
	_anim_enabled = enabled
	if not enabled:
		# 关闭动画时直接显示当前楼层背景
		_load_floor(_current_floor)
		_next_bg.modulate.a = 0.0
		_next_bg.texture = null
