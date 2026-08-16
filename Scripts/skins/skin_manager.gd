extends Node

## 皮肤管理器
## 全局单例：管理可用皮肤列表、当前皮肤选择（持久化到用户设置）

const DEFAULT_SKIN_ID: String = "original"

var skins: Dictionary = {}  # skin_id -> MinoSkin
var current_skin_id: String = DEFAULT_SKIN_ID

# ========== 生命周期 ==========

func _ready():
	_build_default_skins()
	# 从用户设置读取当前皮肤
	var settings: Dictionary = UserSetting.load_settings()
	var saved_skin: String = settings.get("skin", DEFAULT_SKIN_ID)
	if skins.has(saved_skin):
		current_skin_id = saved_skin
	else:
		current_skin_id = DEFAULT_SKIN_ID

## 构建内置皮肤（original = 纯色，tetrio = 贴图）
func _build_default_skins():
	var original := MinoSkin.new()
	original.skin_id = "original"
	original.display_name = "Original"
	original.piece_textures = {}
	skins["original"] = original

	var tetrio := MinoSkin.new()
	tetrio.skin_id = "tetrio"
	tetrio.display_name = "TETR.IO"
	tetrio.piece_textures = {
		"Z": _load_texture("res://Assets/skins/tetrio_minos/Z.png"),
		"L": _load_texture("res://Assets/skins/tetrio_minos/L.png"),
		"O": _load_texture("res://Assets/skins/tetrio_minos/O.png"),
		"S": _load_texture("res://Assets/skins/tetrio_minos/S.png"),
		"I": _load_texture("res://Assets/skins/tetrio_minos/I.png"),
		"J": _load_texture("res://Assets/skins/tetrio_minos/J.png"),
		"T": _load_texture("res://Assets/skins/tetrio_minos/T.png"),
	}
	skins["tetrio"] = tetrio

func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	# 尚未被编辑器导入时，直接从磁盘读取图片
	var img := Image.new()
	if img.load(ProjectSettings.globalize_path(path)) == OK:
		return ImageTexture.create_from_image(img)
	push_warning("皮肤贴图不存在: ", path)
	return null

# ========== 对外接口 ==========

## 获取当前皮肤
func get_current_skin() -> MinoSkin:
	return skins.get(current_skin_id, skins[DEFAULT_SKIN_ID])

## 获取皮肤列表（用于设置界面）
func get_skin_list() -> Array:
	return skins.values()

## 切换皮肤并保存到用户设置
func set_skin(skin_id: String) -> bool:
	if not skins.has(skin_id):
		push_warning("未知皮肤: ", skin_id)
		return false
	current_skin_id = skin_id
	_save_current_skin()
	return true

## 应用皮肤到绘制器（不保存）
func apply_skin_to_drawer(drawer: MinoBoardDrawer) -> void:
	drawer.apply_skin(get_current_skin())

func _save_current_skin():
	var settings: Dictionary = UserSetting.load_settings()
	settings["skin"] = current_skin_id
	UserSetting.save_settings(settings)
