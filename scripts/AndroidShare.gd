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
