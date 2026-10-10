class_name NBAndroidShare
extends RefCounted

# Android 4.7 JavaClassWrapper bridge: share song text with the system chooser.
# Shares text through ACTION_SEND; see share_wav for content-URI audio sharing.
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

# Godot 4.7's Android library already registers an AndroidX FileProvider.
# Its authority is <applicationId>.fileprovider and filesRoot covers filesDir.
# Use the engine's provider directly: no custom manifest, Kotlin or Gradle build.
static func share_wav(path: String) -> bool:
	if OS.get_name() != "Android" or not path.begins_with("user://exports/"):
		return false
	if not path.get_file().begins_with("needlebeat_") or path.get_extension().to_lower() != "wav":
		return false
	if not FileAccess.file_exists(path):
		return false
	var runtime = Engine.get_singleton("AndroidRuntime")
	if runtime == null:
		return false
	var activity = runtime.getActivity()
	if activity == null:
		return false
	var FileClass = JavaClassWrapper.wrap("java.io.File")
	var FileProvider = JavaClassWrapper.wrap("androidx.core.content.FileProvider")
	var file = FileClass.File(ProjectSettings.globalize_path(path))
	var uri = FileProvider.getUriForFile(activity, activity.getPackageName() + ".fileprovider", file)
	if JavaClassWrapper.get_exception() != null or uri == null:
		return false
	var Intent = JavaClassWrapper.wrap("android.content.Intent")
	var ClipData = JavaClassWrapper.wrap("android.content.ClipData")
	var intent = Intent.Intent()
	intent.setAction(Intent.ACTION_SEND)
	intent.setType("audio/wav")
	intent.putExtra(Intent.EXTRA_STREAM, uri)
	intent.setClipData(ClipData.newRawUri("NEEDLEBEAT WAV", uri))
	intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
	var chooser = Intent.createChooser(intent, "Share NEEDLEBEAT WAV")
	chooser.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
	if JavaClassWrapper.get_exception() != null:
		return false
	var launch = func() -> void:
		activity.startActivity(chooser)
	activity.runOnUiThread(runtime.createRunnableFromGodotCallable(launch))
	return JavaClassWrapper.get_exception() == null
