class_name SimReplayBuffer
extends RefCounted

## Append-only SharedCommand tape plus seed (CD-43 command log).
## Hash the tape for deterministic replay identity. This type does not apply
## intents; TraprushGrayboxTapeReplay reads commands and applies them through
## GrayboxCourse. Replay inspector remains out of scope.

var _seed: int = 1
var _commands: Array[SharedCommand] = []


func _init(p_seed: int = 1) -> void:
	_seed = p_seed


func get_seed() -> int:
	return _seed


func size() -> int:
	return _commands.size()


func command_at(index: int) -> SharedCommand:
	if index < 0 or index >= _commands.size():
		return null
	return _commands[index]


func append(command: SharedCommand) -> bool:
	if command == null:
		return false
	if _commands.is_empty():
		if command.sequence < 1:
			return false
	else:
		var last: SharedCommand = _commands[_commands.size() - 1]
		if command.sequence != last.sequence + 1:
			return false
	_commands.append(command)
	return true


func hash_tape() -> PackedByteArray:
	var hasher: StateHasher = StateHasher.new()
	hasher.write_s64(_seed)
	for command: SharedCommand in _commands:
		command.feed_hasher(hasher)
	var digest_hex: String = hasher.digest_hex()
	return digest_hex.hex_decode()
