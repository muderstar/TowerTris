extends CanvasLayer
class_name BackgroundManager

## 塔（Tower）背景管理器
## 根据楼层（stage）切换对应的背景图，楼层变化时做交叉淡入淡出（crossfade）动画。
## 楼层越高，叠加一层逐级变暗变冷的海拔色调（仿 TETR.IO TINT_GRADIENT_BG_BACK）。
## 由 TowerController.stage_changed 信号驱动；背景动画可开关（user_setting 的 bg_animation 键）。

const BG_PATH_PREFIX: String = "res://Assets/bg/zenith_"
const BG_COUNT: int = 10

@export var animation_duration: float = 1.5  # 交叉淡入淡出时长（秒）

## 楼层→背景下标映射（仿 TETR.IO MINIMAL_BGS 阈值表思路：达到阈值即切换）
## 游戏共 18 个楼层（stage 0-17），10 张背景图，每张覆盖约 2 个楼层
const STAGE_TO_BG: Array = [0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 9]

## 每张背景的海拔色调叠加（仿 TETR.IO TINT_GRADIENT_BG_BACK：越高越暗越冷）
## 下标对应 STAGE_TO_BG 中的背景下标
const STAGE_TINTS: Array = [
	Color(1.0, 1.0, 1.0, 0.00),   # zenith_1  无色调
	Color(0.90, 0.95, 1.0, 0.06), # zenith_2
	Color(0.80, 0.90, 1.0, 0.10), # zenith_3
	Color(0.70, 0.80, 1.0, 0.14), # zenith_4
	Color(0.60, 0.70, 1.0, 0.18), # zenith_5
	Color(0.50, 0.60, 0.90, 0.22),# zenith_6
	Color(0.40, 0.50, 0.80, 0.26),# zenith_7
	Color(0.30, 0.40, 0.70, 0.30),# zenith_8
	Color(0.20, 0.30, 0.60, 0.34),# zenith_9
	Color(0.10, 0.15, 0.40, 0.40),# zenith_10 最深
]

var _current_bg: TextureRect = null
var _next_bg: TextureRect = null
var _tint_rect: ColorRect = null
var _anim_enabled: bool = true
var _current_floor: int = 0
var _bg_tween: Tween = null
var _tint_tween: Tween = null

func _ready() -> void:
	_anim_enabled = UserSetting.load_settings().get("bg_animation", true)
	_setup_layers()
	_connect_tower()

## 连接 TowerController 的 stage_changed → 楼层背景切换
func _connect_tower() -> void:
	var tower := get_node_or_null("../TowerController") as Node
	if tower == null:
		push_warning("BackgroundManager: 未找到 TowerController，楼层背景切换不可用")
		return
	if not tower.stage_changed.is_connected(_on_stage_changed):
		tower.stage_changed.connect(_on_stage_changed)

## 楼层变化回调：切换背景图 + 平滑过渡到该楼层的海拔色调
func _on_stage_changed(_previous_stage: int, new_stage: int) -> void:
	var idx: int = _stage_to_bg_index(new_stage)
	set_floor(idx)
	_apply_stage_tint(idx)

## 18 个楼层 → 10 张背景的下标
func _stage_to_bg_index(stage: int) -> int:
	if stage >= 0 and stage < STAGE_TO_BG.size():
		return STAGE_TO_BG[stage]
	return clampi(stage, 0, BG_COUNT - 1)

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
	_tint_rect.color = STAGE_TINTS[0] as Color
	layer.add_child(_tint_rect)
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

## 切换楼层背景（内部经 _on_stage_changed 由 TowerController.stage_changed 驱动）
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
	# 打断进行中的淡化（防止楼层快速连升时多个 tween 互相冲突）
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

## 平滑过渡到指定背景的海拔色调（仿 TETR.IO 海拔渐变：逐层变暗变冷）
func _apply_stage_tint(idx: int) -> void:
	var target: Color = STAGE_TINTS[clampi(idx, 0, STAGE_TINTS.size() - 1)] as Color
	if _tint_tween:
		_tint_tween.kill()
		_tint_tween = null
	if not _anim_enabled:
		_tint_rect.color = target
		return
	_tint_tween = create_tween()
	_tint_tween.tween_property(_tint_rect, "color", target, animation_duration)

## 切换背景动画开关
func set_anim_enabled(enabled: bool) -> void:
	_anim_enabled = enabled
	if not enabled:
		# 关闭动画时直接显示当前楼层背景
		_load_floor(_current_floor)
		_next_bg.modulate.a = 0.0
		_next_bg.texture = null
		_tint_rect.color = STAGE_TINTS[clampi(_current_floor, 0, STAGE_TINTS.size() - 1)] as Color
