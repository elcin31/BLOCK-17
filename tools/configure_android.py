"""Configure this machine's Godot editor for APK export (no project secrets)."""
import json
import os
import re
from pathlib import Path

required = ["GODOT_ANDROID_SDK", "GODOT_JAVA_HOME", "GODOT_ANDROID_KEYSTORE"]
for key in required:
    if not os.environ.get(key):
        raise SystemExit(f"Set {key}")
config_root = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
path = config_root / "godot/editor_settings-4.6.tres"
path.parent.mkdir(parents=True, exist_ok=True)
text = path.read_text() if path.exists() else '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n'
settings = {
    "export/android/android_sdk_path": os.environ["GODOT_ANDROID_SDK"],
    "export/android/java_sdk_path": os.environ["GODOT_JAVA_HOME"],
    "export/android/debug_keystore": os.environ["GODOT_ANDROID_KEYSTORE"],
    "export/android/debug_keystore_user": "androiddebugkey",
    "export/android/debug_keystore_pass": "android",
}
for key, value in settings.items():
    line = f"{key} = {json.dumps(value)}"
    pattern = rf"^{re.escape(key)} = .*?$"
    text = re.sub(pattern, lambda _: line, text, flags=re.M) if re.search(pattern, text, re.M) else text.rstrip() + "\n" + line + "\n"
path.write_text(text)
print("Android SDK and development signing configured.")
