#!/usr/bin/env python3
# The app icon: a ball split between the two players, red on top and blue below, like the iPad between them.
# python3 tools/icon.py → ios/Assets.xcassets/AppIcon.appiconset/icon.png (1024 px, no alpha, as Apple wants)
from pathlib import Path
from PIL import Image, ImageDraw

S, K = 1024, 4  # drawn 4× and scaled down, for smooth edges
OUT = Path(__file__).resolve().parent.parent / 'ios/Assets.xcassets/AppIcon.appiconset/icon.png'
n = S * K
im = Image.new('RGB', (n, n), (228, 53, 13))
d = ImageDraw.Draw(im)
d.rectangle([0, n // 2, n, n], fill=(42, 117, 187))
band = int(n * 0.09)
d.rectangle([0, n // 2 - band // 2, n, n // 2 + band // 2], fill=(20, 20, 24))
r1, r2 = int(n * 0.2), int(n * 0.13)
d.ellipse([n // 2 - r1, n // 2 - r1, n // 2 + r1, n // 2 + r1], fill=(20, 20, 24))
d.ellipse([n // 2 - r2, n // 2 - r2, n // 2 + r2, n // 2 + r2], fill=(250, 250, 250))
im.resize((S, S), Image.LANCZOS).save(OUT)
print('icon →', OUT)
