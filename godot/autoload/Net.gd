extends Node
## HTTP transport to the Levonis backend.
##
## The client is presentation only: it asks for state and posts intents. It
## never sends amounts, prices, timestamps or outcomes — the server derives all
## of those. Every response carries the server clock, which is fed straight
## into ServerClock.
##
## Authentication reuses the platform's own JWT. In a Web export served by
## Levonis the token is read from the same `auth_token` localStorage key the
## store's AuthContext writes, so signing into Levonis signs you into the game.

signal request_failed(path: String, code: int, message: String)
signal unauthorized()

const TIMEOUT_SEC := 20.0

var _base_url: String = ""
var _token: String = ""
var _pool: Array[HTTPRequest] = []
var _in_flight: int = 0


func _ready() -> void:
	_base_url = _resolve_base_url()
	_token = _resolve_token()


## Same-origin when embedded in Levonis; an explicit host for native builds.
func _resolve_base_url() -> String:
	var override := OS.get_environment("LEVO_API_BASE")
	if override != "":
		return override.rstrip("/")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--api="):
			return arg.substr(6).rstrip("/")
	if OS.has_feature("web"):
		return ""  # served from the same origin as the platform
	return "http://localhost:3000"


## Read the platform's JWT. Web reads the shared localStorage key; native
## builds fall back to a locally cached token from a previous sign-in.
func _resolve_token() -> String:
	if OS.has_feature("web") and Engine.has_singleton("JavaScriptBridge"):
		var js := Engine.get_singleton("JavaScriptBridge")
		var value = js.eval("window.localStorage.getItem('auth_token') || ''", true)
		if typeof(value) == TYPE_STRING and value != "":
			return value
	var cfg := ConfigFile.new()
	if cfg.load("user://session.cfg") == OK:
		return String(cfg.get_value("auth", "token", ""))
	return ""


## Store a token obtained outside the game (deep link, native sign-in).
func set_token(token: String) -> void:
	_token = token
	var cfg := ConfigFile.new()
	cfg.load("user://session.cfg")
	cfg.set_value("auth", "token", token)
	cfg.save("user://session.cfg")


func has_token() -> bool:
	return _token != ""


func base_url() -> String:
	return _base_url


func _take_request() -> HTTPRequest:
	if _pool.is_empty():
		var http := HTTPRequest.new()
		http.timeout = TIMEOUT_SEC
		http.use_threads = not OS.has_feature("web")
		add_child(http)
		return http
	return _pool.pop_back()


func _release_request(http: HTTPRequest) -> void:
	if _pool.size() < 4:
		_pool.append(http)
	else:
		http.queue_free()


func _headers() -> PackedStringArray:
	var headers := PackedStringArray(["Content-Type: application/json"])
	if _token != "":
		headers.append("Authorization: Bearer " + _token)
	return headers


## Perform a request and return the decoded body. Errors surface as a
## dictionary with `success: false` so callers have one shape to handle.
func request(method: int, path: String, body: Variant = null) -> Dictionary:
	var http := _take_request()
	var url := _base_url + path
	var payload := "" if body == null else JSON.stringify(body)
	var started := Time.get_ticks_msec()
	_in_flight += 1

	var err := http.request(url, _headers(), method, payload)
	if err != OK:
		_in_flight -= 1
		_release_request(http)
		request_failed.emit(path, -1, "request_failed")
		return {"success": false, "error": "network"}

	var result: Array = await http.request_completed
	_in_flight -= 1
	_release_request(http)

	var response_code: int = result[1]
	var raw: PackedByteArray = result[3]

	if response_code == 401:
		unauthorized.emit()
		return {"success": false, "error": "unauthenticated"}

	var text := raw.get_string_from_utf8()
	if text.strip_edges() == "":
		request_failed.emit(path, response_code, "empty_response")
		return {"success": false, "error": "network"}
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		request_failed.emit(path, response_code, "bad_response")
		return {"success": false, "error": "bad_response"}

	var data: Dictionary = parsed
	# Any response carrying the server clock re-syncs it, latency corrected.
	if data.has("serverNow"):
		ServerClock.sync(int(data["serverNow"]), started)

	if response_code >= 400 and not data.has("error"):
		data["success"] = false
		data["error"] = "http_%d" % response_code
	return data


func get_json(path: String) -> Dictionary:
	return await request(HTTPClient.METHOD_GET, path)


func post_json(path: String, body: Dictionary) -> Dictionary:
	return await request(HTTPClient.METHOD_POST, path, body)


func busy() -> bool:
	return _in_flight > 0
