# Build app/icon.ico from app/icon.png.
# app/icon.png is decoded at build time from the iOS project's
# AppIcon-1024.png.b64 (the blue walkie-talkie original).
# Runs on the Windows build runner: pip install pillow first.
# Paths are resolved relative to this script, so it works no matter
# which directory the runner invokes it from.
import os

from PIL import Image

_here = os.path.dirname(os.path.abspath(__file__))
src = os.path.join(_here, "..", "app", "icon.png")
dst = os.path.join(_here, "..", "app", "icon.ico")
img = Image.open(src).convert("RGBA")
img.save(dst, format="ICO", sizes=[(16, 16), (32, 32), (48, 48), (256, 256)])
print("icon.ico written")
