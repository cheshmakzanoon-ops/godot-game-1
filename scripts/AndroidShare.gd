class_name NBAndroidShare
extends RefCounted

# Android 4.7 JavaClassWrapper bridge: share song text with the system chooser.
# Never pass a file:// URI to a third-party app. PCM .wav files are exported
# to app storage; third-party WAV sharing needs a separate FileProvider bridge.
static func share_code(code: String) -> bool:
	if OS.get_name() != "Android":
		return false
	var runtime = Engine.get_singleton("AndroidRuntime")
	if runtime == null:
		return false
	var activity = runtime.getActivity()
	if activity == null:
		return false
	var Intent = JavaClassWrapper.wrap("android.content.Intent")
	var intent = Intent.Intent()
	intent.setAction(Intent.ACTION_SEND)
	intent.putExtra(Intent.EXTRA_TEXT, "NEEDLEBEAT: DROP\n" + code)
	intent.setType("text/plain")
	var chooser = Intent.createChooser(intent, "Share NEEDLEBEAT song")
	var share_task = func() -> void:
		activity.startActivity(chooser)
	activity.runOnUiThread(runtime.createRunnableFromGodotCallable(share_task))
	return true

# The Gradle-only Java bridge exposes a private cache file with a temporary
# content:// URI. Desktop exports remain available without Android dependencies.
static func share_wav(path: String) -> bool:
	if OS.get_name() != "Android" or not FileAccess.file_exists(path):
		return false
	var runtime = Engine.get_singleton("AndroidRuntime")
	if runtime == null:
		return false
	var activity = runtime.getActivity()
	if activity == null:
		return false
	var bridge = JavaClassWrapper.wrap("com.needlebeat.drop.NeedlebeatShare")
	if bridge == null:
		return false
	var accepted: bool = bridge.shareWav(activity, ProjectSettings.globalize_path(path))
	var java_error = JavaClassWrapper.get_exception()
	if java_error != null:
		push_warning("Android WAV share error: " + str(java_error))
		return false
	return accepted
