extends Node
## Lightweight arcade audio. Looping BGM plus one-shot SFX.
## WAVs under res://assets/audio/ are original synthesized tones (not commercial tracks).
## Missing files warn and are skipped so a run still plays.

const MUSIC_PATH := "res://assets/audio/bgm_loop.wav"
const DRIVE_PATH := "res://assets/audio/bgm_drive.wav"
const SFX_PATHS := {
	"jump": "res://assets/audio/sfx_jump.wav",
	"lane": "res://assets/audio/sfx_lane.wav",
	"coin": "res://assets/audio/sfx_coin.wav",
	"boost": "res://assets/audio/sfx_boost.wav",
	"crash": "res://assets/audio/sfx_crash.wav",
}

var _music: AudioStreamPlayer
var _drive: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_cursor := 0
var _streams: Dictionary = {}
var _speed_energy := 0.0
var _danger_energy := 0.0

func _ready() -> void:
	# Stay alive across the game-over pause so crash SFX can finish
	# and stop_music() still runs after the tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music = AudioStreamPlayer.new()
	_music.name = "BGM"
	_music.volume_db = -12.0
	# Explicit pausable: do not inherit this node's ALWAYS mode.
	_music.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_music)
	var music := _load_wav(MUSIC_PATH, true)
	if music:
		_music.stream = music
	# Same-length layer: hats and arp that rise with speed or chaser danger.
	_drive = AudioStreamPlayer.new()
	_drive.name = "BGMDrive"
	_drive.volume_db = -32.0
	_drive.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_drive)
	var drive := _load_wav(DRIVE_PATH, true)
	if drive:
		_drive.stream = drive
	for i in 5:
		var p := AudioStreamPlayer.new()
		p.name = "SFX%d" % i
		p.volume_db = -6.0
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_sfx_players.append(p)

func start_music() -> void:
	_speed_energy = 0.0
	_danger_energy = 0.0
	_apply_drive()
	# Restart both from the top so the layers stay locked and a new run
	# does not resume mid-loop.
	for player in [_music, _drive]:
		if player == null or player.stream == null:
			continue
		player.stream_paused = false
		player.play(0.0)

func stop_music() -> void:
	for player in [_music, _drive]:
		if player:
			player.stop()

func set_speed_energy(amount: float) -> void:
	_speed_energy = clampf(amount, 0.0, 1.0)
	_apply_drive()

func set_danger_energy(amount: float) -> void:
	_danger_energy = clampf(amount, 0.0, 1.0)
	_apply_drive()

func _apply_drive() -> void:
	if _drive == null:
		return
	var energy := maxf(_speed_energy, _danger_energy)
	_drive.volume_db = lerpf(-32.0, -10.0, energy)

func play_sfx(id: String) -> void:
	if _sfx_players.is_empty():
		return
	var stream: AudioStream = _streams.get(id, null)
	if stream == null:
		var path: String = str(SFX_PATHS.get(id, ""))
		if path == "":
			return
		stream = _load_wav(path, false)
		if stream == null:
			return
		_streams[id] = stream
	var player := _sfx_players[_sfx_cursor]
	_sfx_cursor = (_sfx_cursor + 1) % _sfx_players.size()
	player.stream = stream
	player.play()

func _load_wav(path: String, looped: bool) -> AudioStreamWAV:
	if not FileAccess.file_exists(path):
		push_warning("Missing audio, skipping: %s" % path)
		return null
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.size() < 44:
		push_warning("Audio unreadable, skipping: %s" % path)
		return null
	if bytes.slice(0, 4).get_string_from_ascii() != "RIFF":
		push_warning("Audio is not a WAV, skipping: %s" % path)
		return null
	var channels := 1
	var sample_rate := 22050
	var bits := 16
	var audio_format := 1
	var data := PackedByteArray()
	var i := 12
	while i + 8 <= bytes.size():
		var chunk_id := bytes.slice(i, i + 4).get_string_from_ascii()
		var chunk_size := int(bytes.decode_u32(i + 4))
		var start := i + 8
		if start + chunk_size > bytes.size():
			break
		if chunk_id == "fmt " and chunk_size >= 16:
			audio_format = int(bytes.decode_u16(start))
			channels = int(bytes.decode_u16(start + 2))
			sample_rate = int(bytes.decode_u32(start + 4))
			bits = int(bytes.decode_u16(start + 14))
		elif chunk_id == "data":
			data = bytes.slice(start, start + chunk_size)
		var step := chunk_size + (chunk_size & 1)
		if step <= 0:
			break
		i = start + step
	if audio_format != 1 or data.is_empty() or (bits != 16 and bits != 8):
		push_warning("Unsupported WAV, skipping: %s" % path)
		return null
	var stream := AudioStreamWAV.new()
	stream.data = data
	stream.mix_rate = sample_rate
	stream.stereo = channels >= 2
	stream.format = AudioStreamWAV.FORMAT_16_BITS if bits == 16 else AudioStreamWAV.FORMAT_8_BITS
	if looped and "loop_mode" in stream:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		var frames := data.size()
		if bits == 16:
			frames = int(frames / 2)
		if channels >= 2:
			frames = int(frames / 2)
		stream.loop_begin = 0
		stream.loop_end = frames
	return stream
