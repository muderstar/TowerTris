extends Node

## 音频管理器
## 全局单例：加载并播放音效（SFX），支持多路混音与音量控制

const SFX_DIR: String = "res://Assets/sfx/"

# 全部音效文件名（不含扩展名）。
# 注意：导出后 res:// 是打包的 PCK，无法用 DirAccess 枚举目录，
# 因此必须用显式列表 + load() 加载（编辑器与导出包均可用）。
# 此列表由 Assets/sfx 目录中的 .ogg 生成（base-tetrio-sfx-export）。
const SOUND_NAMES: Array[String] = [
	"achievement_1", "achievement_2", "achievement_3", "allclear", "applause", "b2bcharge_1", "b2bcharge_2", "b2bcharge_3",
	"b2bcharge_4", "b2bcharge_blast_1", "b2bcharge_blast_2", "b2bcharge_blast_3", "b2bcharge_blast_4", "b2bcharge_danger", "b2bcharge_distance_1", "b2bcharge_distance_2",
	"b2bcharge_distance_3", "b2bcharge_start", "boardappear", "boardlock", "boardlock_clear", "boardlock_clink", "boardlock_fail", "boardlock_revive",
	"bombdetonate", "btb_1", "btb_2", "btb_3", "btb_break", "card_reverse_impact", "card_select", "card_select_reverse",
	"card_slide_1", "card_slide_2", "card_slide_3", "card_slide_4", "card_tone_allspin", "card_tone_allspin_reverse", "card_tone_doublehole", "card_tone_doublehole_reverse",
	"card_tone_duo", "card_tone_duo_reverse", "card_tone_expert", "card_tone_expert_reverse", "card_tone_gravity", "card_tone_gravity_reverse", "card_tone_invisible", "card_tone_invisible_reverse",
	"card_tone_messy", "card_tone_messy_reverse", "card_tone_nohold", "card_tone_nohold_reverse", "card_tone_volatile", "card_tone_volatile_reverse", "clearbtb", "clearline",
	"clearquad", "clearspin", "clutch", "collapse", "combo_1", "combo_10", "combo_10_power", "combo_11",
	"combo_11_power", "combo_12", "combo_12_power", "combo_13", "combo_13_power", "combo_14", "combo_14_power", "combo_15",
	"combo_15_power", "combo_16", "combo_16_power", "combo_1_power", "combo_2", "combo_2_power", "combo_3", "combo_3_power",
	"combo_4", "combo_4_power", "combo_5", "combo_5_power", "combo_6", "combo_6_power", "combo_7", "combo_7_power",
	"combo_8", "combo_8_power", "combo_9", "combo_9_power", "combobreak", "countdown1", "countdown2", "countdown3",
	"countdown4", "countdown5", "counter", "cutin_superlobby", "damage_alert", "damage_large", "damage_medium", "damage_small",
	"death", "detonate1", "detonate2", "detonated", "elim", "exchange", "failure", "finessefault",
	"finish", "fire", "floor", "gameover", "garbage_in_large", "garbage_in_medium", "garbage_in_small", "garbage_out_large",
	"garbage_out_medium", "garbage_out_small", "garbagerise", "garbagesmash", "garbagewindup_1", "garbagewindup_2", "garbagewindup_3", "garbagewindup_4",
	"go", "harddrop", "hit", "hold", "hyperalert", "i", "ihs", "impact",
	"inject", "irs", "j", "l", "level1", "level10", "level100", "level500",
	"levelup", "losestock", "maintenance", "map_change", "matchintro", "menuback", "menuclick", "menuconfirm",
	"menuhit1", "menuhit2", "menuhit3", "menuhover", "menutap", "metronome", "metronome_down", "mission",
	"mission_free", "mission_league", "mission_versus", "mmstart", "move", "no", "notify", "o",
	"offset", "party_ready", "pause_continue", "pause_exit", "pause_retry", "pause_start", "personalbest", "piece_change",
	"protected_large", "protected_medium", "protected_small", "purchase_start", "queue_change", "ranklower", "rankraise", "ratinglower",
	"ratingraise", "redo", "ribbon", "ribbon_off", "ribbon_on", "ribbon_tap", "rotate", "rsg",
	"rsg_go", "s", "scoreslide_in", "scoreslide_out", "se_vol_blip", "shatter", "showscore", "sidehit",
	"social_close", "social_close_minor", "social_dm", "social_invite", "social_notify_major", "social_notify_minor", "social_offline", "social_online",
	"social_open", "social_open_minor", "softdrop", "speed_tick_1", "speed_tick_2", "speed_tick_3", "speed_tick_4", "speed_tick_whirl",
	"spin", "spinend", "staffsilence", "staffspam", "staffwarning", "supporter", "t", "target",
	"thunder1", "thunder2", "thunder3", "thunder4", "thunder5", "thunder6", "timer1", "timer2",
	"topout", "undo", "userjoin", "userleave", "victory", "voidhole", "warning", "warp",
	"worldrecord", "wound", "wound_repel", "z", "zenith_downspeed_a", "zenith_downspeed_ahalfsharp", "zenith_downspeed_b", "zenith_downspeed_c",
	"zenith_downspeed_csharp", "zenith_downspeed_e", "zenith_downspeed_fsharp", "zenith_downspeed_g", "zenith_levelup_a", "zenith_levelup_ahalfsharp", "zenith_levelup_b", "zenith_levelup_c",
	"zenith_levelup_e", "zenith_levelup_fsharp", "zenith_levelup_g", "zenith_speedrun_end", "zenith_speedrun_start", "zenith_split_cleared", "zenith_split_missed", "zenith_start",
	"zenith_start_duo", "zenith_upspeed_a", "zenith_upspeed_ahalfsharp", "zenith_upspeed_b", "zenith_upspeed_c", "zenith_upspeed_csharp", "zenith_upspeed_e", "zenith_upspeed_fsharp",
	"zenith_upspeed_g",
]

# 预加载的音效表（名称 → AudioStream）
var sounds: Dictionary = {}

# 播放器池（允许同音效叠加播放）
var _players: Array[AudioStreamPlayer] = []

# 音量设置（分贝）
var sfx_volume_db: float = 0.0

# ========== 生命周期 ==========

func _ready():
	_register_all_sounds()
	_build_player_pool()

## 注册全部音效（显式列表加载，兼容编辑器与导出包）
func _register_all_sounds():
	for name in SOUND_NAMES:
		var stream = _load_stream(SFX_DIR + name + ".ogg")
		if stream:
			sounds[name] = stream
	if sounds.is_empty():
		push_warning("未加载到任何音效，请检查 res://Assets/sfx/ 资源是否已导入")

func _load_stream(path: String) -> AudioStream:
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is AudioStream:
			return res
	return null

## 预创建一批播放器用于混音（更大的池 + 每条音效独立播放，减少互相打断）
func _build_player_pool(pool_size: int = 24):
	for i in range(pool_size):
		var player := AudioStreamPlayer.new()
		player.volume_db = sfx_volume_db
		add_child(player)
		_players.append(player)

# ========== 对外接口 ==========

## 播放音效（name 为文件名，不含扩展名）
## 自动从池中选取空闲播放器；全部占用时复用"已播放最久"的播放器，
## 保证新的音效总能播出，且不会频繁打断刚响起的音效。
func play(name: String, volume_db: float = 0.0, pitch_scale: float = 1.0):
	if not sounds.has(name):
		push_warning("音效不存在: ", name)
		return
	var player: AudioStreamPlayer = _get_free_player()
	if player == null:
		return
	player.stream = sounds[name]
	player.volume_db = sfx_volume_db + volume_db
	player.pitch_scale = pitch_scale
	player.play()

## 停止某个音效
func stop(name: String):
	for player in _players:
		if player.stream == sounds.get(name):
			player.stop()

## 停止所有音效
func stop_all():
	for player in _players:
		player.stop()

## 设置音效音量（分贝）
func set_sfx_volume(value_db: float):
	sfx_volume_db = value_db
	for player in _players:
		player.volume_db = sfx_volume_db

## 获取空闲播放器；全部占用时复用已播放时间最长的那个（最早开始 → 最接近自然结束）。
## 不再总是复用 _players[0]（那会反复打断同一个播放器上的音效）。
func _get_free_player() -> AudioStreamPlayer:
	var free: Array[AudioStreamPlayer] = []
	for player in _players:
		if not player.playing:
			free.append(player)
	if not free.is_empty():
		return free[0]
	# 全部占用：找出播放最久的（get_playback_position 相对播放长度，最接近结束）
	var oldest: AudioStreamPlayer = _players[0]
	var oldest_remain: float = 1e9
	for player in _players:
		var stream_len: float = player.stream.get_length() if player.stream else 0.0
		var remain: float = stream_len - player.get_playback_position()
		if remain < oldest_remain:
			oldest_remain = remain
			oldest = player
	return oldest
