"""Run the exported APK, tap its UI and verify real Android save restoration."""
import hashlib
import atexit
import json
import re
import struct
import subprocess
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PACKAGE = 'org.block17.livingcity'


def adb(*args, binary=False):
    result = subprocess.run(['adb', *args], check=True, capture_output=True, timeout=90)
    return result.stdout if binary else result.stdout.decode('utf-8', errors='replace').strip()


def tap(x, y):
    adb('shell', 'input', 'tap', str(x), str(y))
    time.sleep(1)


def screenshot(name):
    data = adb('exec-out', 'screencap', '-p', binary=True)
    assert data[:8] == b'\x89PNG\r\n\x1a\n', 'valid Android screenshot'
    width, height = struct.unpack('>II', data[16:24])
    assert (width, height) == (1280, 720), f'landscape viewport: {width}x{height}'
    (ROOT / 'builds' / name).write_bytes(data)
    assert len(data) > 30000, 'rendered scene is not blank'


def read_save():
    paths = adb('shell', 'run-as', PACKAGE, 'find', 'files', '-name', 'block17_autosave.json').splitlines()
    assert paths, 'Android app wrote an autosave in private storage'
    raw = adb('exec-out', 'run-as', PACKAGE, 'cat', paths[0])
    envelope = json.loads(raw)
    assert hashlib.sha256(envelope['payload'].encode()).hexdigest() == envelope['checksum']
    state = json.loads(envelope['payload'])['simulation']
    assert len(state['residents']) == 120
    assert state['version'] == 1
    return state


def launch():
    adb('shell', 'am', 'start', '-W', '-n', PACKAGE + '/com.godot.game.GodotAppLauncher')
    time.sleep(5)
    assert adb('shell', 'pidof', PACKAGE), 'game process alive'


def collect_logs():
    try:
        (ROOT / 'builds/android-runtime.log').write_text(adb('logcat', '-d'))
    except (subprocess.SubprocessError, OSError):
        pass


atexit.register(collect_logs)


adb('wait-for-device')
assert adb('shell', 'getprop', 'sys.boot_completed') == '1'
adb('shell', 'wm', 'size', '720x1280')
adb('shell', 'settings', 'put', 'global', 'airplane_mode_on', '1')
adb('shell', 'svc', 'wifi', 'disable')
adb('shell', 'svc', 'data', 'disable')
adb('install', '--no-streaming', str(ROOT / 'builds/BLOCK-17.apk'))
adb('logcat', '-c')
launch()
screenshot('android-01-menu.png')
tap(200, 388)  # New game
time.sleep(3)
adb('shell', 'input', 'swipe', '550', '400', '720', '400', '250')
tap(1225, 668)  # Zoom in
screenshot('android-02-city.png')
tap(310, 668)  # Residents
screenshot('android-03-residents.png')
tap(1225, 138)  # Close panel
tap(80, 50)  # Menu writes an autosave
saved = read_save()
adb('shell', 'am', 'force-stop', PACKAGE)
launch()
tap(200, 442)  # Continue after a real process restart
time.sleep(3)
screenshot('android-04-restored.png')
tap(80, 50)
restored = read_save()
assert restored['residents'][0]['name'] == saved['residents'][0]['name']
assert restored['day'] * 1440 + restored['minute'] > saved['day'] * 1440 + saved['minute'], 'restored city continued running'
assert len(restored['buildings']) == len(saved['buildings'])
logs = adb('logcat', '-d')
(ROOT / 'builds/android-runtime.log').write_text(logs)
assert not re.search(r'SCRIPT ERROR|FATAL EXCEPTION|Fatal signal|Failed to load script', logs), 'no script/native crashes'
assert adb('shell', 'settings', 'get', 'global', 'airplane_mode_on') == '1'
print('ANDROID: install, offline launch, landscape render, touch/drag/zoom, residents panel, autosave and process-restart restoration PASS')
