extends Node
## Sound.
##
## Short, quiet cues only — a tap should never nag. Every sound is optional:
## if a cue's file is missing the call is a silent no-op, so the game runs the
## same with or without the audio bank. The mute setting is honoured everywhere
## and persisted with the player's other preferences.

const SFX_DIR := "res://assets/sfx/"
const CUES := {
	"tap": "ui_tap.wav",
	"print_start": "print_start.wav",
	"job_complete": "job_complete.wav",
	"coin": "coin.wav",
	"order_new": "order_new.wav",
	"failure": "failure.wav",
	"level_up": "level_up.wav",
	"purchase": "purchase.wav",
	"expand": "expand.wav",
}

## Voices, so overlapping cues do not cut each other off.
const VOICES := 6

var muted: bool = false:
	set(value):
		muted = value
		_save()

var volume_db: float = -6.0

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
## Debounce identical cues so a burst of events is one sound, not twenty.
var _last_played: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		player.volume_db = volume_db
		add_child(player)
		_players.append(player)
	for key in CUES:
		var path: String = SFX_DIR + CUES[key]
		if ResourceLoader.exists(path):
			_streams[key] = load(path)


func play(cue: String, pitch: float = 1.0) -> void:
	if muted or not _streams.has(cue):
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_played.get(cue, -9999)) < 60:
		return
	_last_played[cue] = now

	var player := _players[_next_voice]
	_next_voice = (_next_voice + 1) % VOICES
	player.stream = _streams[cue]
	player.pitch_scale = clampf(pitch, 0.6, 1.6)
	player.volume_db = volume_db
	player.play()


func toggle_mute() -> bool:
	muted = not muted
	return muted


func _settings_path() -> String:
	return "user://settings.cfg"


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(_settings_path()) == OK:
		muted = bool(cfg.get_value("audio", "muted", false))
		volume_db = float(cfg.get_value("audio", "volume_db", -6.0))


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(_settings_path())
	cfg.set_value("audio", "muted", muted)
	cfg.set_value("audio", "volume_db", volume_db)
	cfg.save(_settings_path())
