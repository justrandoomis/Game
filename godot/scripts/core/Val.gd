class_name Val
extends RefCounted
## Safe coercion for values that arrive from the server.
##
## JSON nulls are real: a job that has not started has `startedAt: null`, an
## offer that has not been accepted has `dueAt: null`. Godot's int()/String()
## constructors throw on null, so every read of a nullable field goes through
## here and gets a sensible default instead of an error.

static func num(value: Variant, fallback: float = 0.0) -> float:
	match typeof(value):
		TYPE_INT, TYPE_FLOAT:
			return float(value)
		TYPE_STRING:
			return float(String(value)) if String(value).is_valid_float() else fallback
		_:
			return fallback


static func int_of(value: Variant, fallback: int = 0) -> int:
	return int(num(value, float(fallback)))


static func text(value: Variant, fallback: String = "") -> String:
	return String(value) if typeof(value) == TYPE_STRING else fallback


static func flag(value: Variant, fallback: bool = false) -> bool:
	return bool(value) if typeof(value) == TYPE_BOOL else fallback


## Read a possibly-null field off a server dictionary in one step.
static func field(source: Dictionary, key: String, fallback: float = 0.0) -> float:
	return num(source.get(key, null), fallback)


static func field_int(source: Dictionary, key: String, fallback: int = 0) -> int:
	return int_of(source.get(key, null), fallback)


static func field_text(source: Dictionary, key: String, fallback: String = "") -> String:
	return text(source.get(key, null), fallback)
