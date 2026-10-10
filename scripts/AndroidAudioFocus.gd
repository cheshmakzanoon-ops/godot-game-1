class_name NBAndroidAudioFocus
extends Node

# Explicit, transient Android audio focus. The engine also suspends its audio
# driver on focus-out; this listener handles *audio-only* interruptions such as
# another app or a call acquiring focus while our Activity remains visible.
# Do not automatically restart music on a focus gain: player consent is required.
signal focus_lost(change: int)

const FOCUS_GAIN := 1
const FOCUS_LOSS := -1
const FOCUS_LOSS_TRANSIENT := -2
const FOCUS_LOSS_CAN_DUCK := -3

var manager: Variant = null
var listener: Variant = null
var requested := false
var acquired := false
var supported := false

func _ready() -> void:
	if OS.get_name() != "Android":
		return
	var runtime = Engine.get_singleton("AndroidRuntime")
	if runtime == null:
		push_warning("AndroidRuntime unavailable: using Godot activity-focus fallback")
		return
	var context = runtime.getApplicationContext()
	if context == null:
		return
	manager = context.getSystemService("audio")
	if manager == null:
		return
	listener = JavaClassWrapper.create_sam_callback(
		"android.media.AudioManager$OnAudioFocusChangeListener", _on_focus_callback)
	if listener == null or JavaClassWrapper.get_exception() != null:
		listener = null
		return
	# requestAudioFocus(OnAudioFocusChangeListener, STREAM_MUSIC, GAIN) is
	# available on every supported Android API level. Godot 4.7's JNI wrapper
	# cannot instantiate AudioAttributes$Builder on all builds (its nested
	# constructor is not exposed as "Builder"), so do not fail app startup.
	supported = true

func request_focus() -> bool:
	# Desktop and older AndroidRuntime-less exports still use the engine's
	# ordinary pause/focus notifications; never break playable offline mode.
	if not supported:
		requested = true
		acquired = true
		return true
	if acquired:
		return true
	var result: int = 0
	result = int(manager.requestAudioFocus(listener, 3, FOCUS_GAIN))
	if JavaClassWrapper.get_exception() != null:
		result = 0
	requested = result == FOCUS_GAIN
	acquired = requested
	return acquired

func abandon_focus() -> void:
	# Mark inactive *before* abandoning, so a late Java callback cannot restart
	# or re-pause a new stage. No focus is held while the game is user-paused.
	var had_request := requested
	requested = false
	acquired = false
	if not had_request or not supported:
		return
	manager.abandonAudioFocus(listener)

func _on_focus_callback(change: int) -> void:
	# Android invokes this on a platform thread. Schedule the state transition
	# on the Godot main thread, not from inside the JNI callback.
	call_deferred("_apply_focus_change", change)

func _apply_focus_change(change: int) -> void:
	if not requested:
		return
	if change == FOCUS_GAIN:
		acquired = true
		return
	if change in [FOCUS_LOSS, FOCUS_LOSS_TRANSIENT, FOCUS_LOSS_CAN_DUCK]:
		acquired = false
		focus_lost.emit(change)

func _exit_tree() -> void:
	abandon_focus()
