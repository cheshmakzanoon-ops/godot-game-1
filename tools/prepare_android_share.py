#!/usr/bin/env python3
"""Overlay NEEDLEBEAT's Java FileProvider bridge on a Godot 4.7 Gradle template.

Run AFTER `godot --install-android-build-template`; do not commit android/build.
"""
from pathlib import Path
import shutil
import sys
import xml.etree.ElementTree as ET


def install(project: Path) -> None:
    template = project / "android" / "build"
    manifest = template / "src/main/AndroidManifest.xml"
    gradle = template / "build.gradle"
    native = project / "android_native"
    if not manifest.is_file() or not gradle.is_file():
        raise RuntimeError("Godot Android Gradle template missing; install it first")
    text = manifest.read_text(encoding="utf-8")
    provider_xml = (native / "provider.xml").read_text(encoding="utf-8")
    if "${applicationId}.share" not in text:
        if text.count("</application>") != 1:
            raise RuntimeError("Unknown Android manifest structure")
        text = text.replace("</application>", provider_xml + "    </application>")
        ET.fromstring(text)
        manifest.write_text(text, encoding="utf-8")
    app_gradle = gradle.read_text(encoding="utf-8")
    dependency = '    implementation "androidx.core:core:1.13.1"\n'
    if dependency.strip() not in app_gradle:
        if app_gradle.count("dependencies {") != 1:
            raise RuntimeError("Unknown Gradle build structure")
        app_gradle = app_gradle.replace("dependencies {", "dependencies {\n" + dependency, 1)
        gradle.write_text(app_gradle, encoding="utf-8")
    for rel in ["src/main/java/com/needlebeat/drop/NeedlebeatShare.java",
                "src/main/res/xml/needlebeat_share_paths.xml"]:
        dest = template / rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(native / rel, dest)
    print("Installed NEEDLEBEAT Android FileProvider share bridge")


if __name__ == "__main__":
    install(Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path.cwd())
