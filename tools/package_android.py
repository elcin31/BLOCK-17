"""Produce the requested ZIP and a SHA-256 manifest from a verified APK."""
from pathlib import Path
from hashlib import sha256
from zipfile import ZipFile, ZIP_DEFLATED

root = Path(__file__).resolve().parents[1]
apk = root / "builds/BLOCK-17.apk"
if not apk.is_file():
    raise SystemExit("Build builds/BLOCK-17.apk first")
digest = sha256(apk.read_bytes()).hexdigest()
manifest = f"{digest}  BLOCK-17.apk\n"
(root / "builds/SHA256SUMS.txt").write_text(manifest)
instructions = """BLOCK 17 · 0.1.0

Установка: распакуйте архив, откройте BLOCK-17.apk на Android и разрешите
установку из выбранного приложения. Android 7.0+ / OpenGL ES 3.0,
ARM64, ARMv7 или x86_64. Интернет и регистрация не нужны.

Это установочная сборка, подписанная ключом разработки (debug).
Она предназначена для прямой установки, а не публикации в Google Play.
При смене ключа следующую сборку придётся устанавливать после удаления
предыдущей. Удаление приложения удаляет локальные сохранения.

Перемещение: потяните карту. Масштаб: два пальца или кнопки + / −.
Касание жителя: карточка и слежение. «B / 17»: главное меню.
Время: пауза, 1×, 2×, 4×. Автосохранение — раз в минуту и при сворачивании.

Исходный код: https://github.com/elcin31/BLOCK-17
Проверенные системы и ограничения: docs/TEST-REPORT.md в репозитории.
"""
with ZipFile(root / "builds/BLOCK-17-Android.zip", "w", ZIP_DEFLATED, compresslevel=6) as archive:
    archive.write(apk, "BLOCK-17.apk")
    archive.writestr("SHA256SUMS.txt", manifest)
    archive.writestr("УСТАНОВКА.txt", instructions)
print(f"BLOCK-17-Android.zip · APK SHA256 {digest}")
