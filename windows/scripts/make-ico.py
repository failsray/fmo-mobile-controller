# Build app/icon.ico from app/icon.png.
# app/icon.png is decoded at build time from the iOS project's
# AppIcon-1024.png.b64 (the blue walkie-talkie original).
# Runs on the Windows build runner: pip install pillow first.
from PIL import Image

src = "app/icon.png"
img = Image.open(src).convert("RGBA")
img.save("app/icon.ico", format="ICO", sizes=[(16, 16), (32, 32), (48, 48), (256, 256)])
print("icon.ico written")
