"""Membuat semua ukuran AppIcon iOS dari Icon-App-1024x1024@1x.png.

Jalankan setelah `flutter test tool/ekspor_ikon_test.dart`:
    python tool/ikon_ios.py
"""
import json
from pathlib import Path

from PIL import Image

folder = Path("ios/Runner/Assets.xcassets/AppIcon.appiconset")
sumber = Image.open(folder / "Icon-App-1024x1024@1x.png").convert("RGB")

for gambar in json.loads((folder / "Contents.json").read_text())["images"]:
    nama = gambar.get("filename")
    if not nama or nama.startswith("Icon-App-1024"):
        continue
    sisi = float(gambar["size"].split("x")[0]) * int(gambar["scale"].rstrip("x"))
    px = round(sisi)
    sumber.resize((px, px), Image.LANCZOS).save(folder / nama)
    print(nama, px)
