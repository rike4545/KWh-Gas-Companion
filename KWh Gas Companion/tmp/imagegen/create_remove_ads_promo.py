from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont


SIZE = 1024
OUT = Path("/Users/bryan/Documents/KWh Gas Companion/KWh Gas Companion/output/imagegen/remove-ads-promo-1024.png")
OUT.parent.mkdir(parents=True, exist_ok=True)

font_bold = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
font_regular = "/System/Library/Fonts/Supplemental/Arial.ttf"


def rounded_rect_mask(size, radius):
    mask = Image.new("L", size, 0)
    d = ImageDraw.Draw(mask)
    d.rounded_rectangle((0, 0, size[0], size[1]), radius=radius, fill=255)
    return mask


img = Image.new("RGB", (SIZE, SIZE), "#08111f")
draw = ImageDraw.Draw(img)

# Background gradient
for y in range(SIZE):
    t = y / (SIZE - 1)
    r = int(8 + (19 - 8) * t)
    g = int(17 + (24 - 17) * t)
    b = int(31 + (38 - 31) * t)
    draw.line((0, y, SIZE, y), fill=(r, g, b))

# Accent glow layers
glow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
gdraw = ImageDraw.Draw(glow)
gdraw.ellipse((70, 120, 620, 720), fill=(225, 52, 64, 110))
gdraw.ellipse((450, 80, 980, 610), fill=(37, 138, 255, 70))
gdraw.ellipse((120, 600, 880, 1120), fill=(255, 171, 64, 55))
glow = glow.filter(ImageFilter.GaussianBlur(70))
img = Image.alpha_composite(img.convert("RGBA"), glow)

# Subtle grid lines
overlay = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
odraw = ImageDraw.Draw(overlay)
for x in range(96, SIZE, 96):
    odraw.line((x, 0, x, SIZE), fill=(255, 255, 255, 16), width=1)
for y in range(96, SIZE, 96):
    odraw.line((0, y, SIZE, y), fill=(255, 255, 255, 14), width=1)
img = Image.alpha_composite(img, overlay)

# Main card
card = Image.new("RGBA", (760, 760), (0, 0, 0, 0))
cshadow = Image.new("RGBA", (760, 760), (0, 0, 0, 0))
csdraw = ImageDraw.Draw(cshadow)
csdraw.rounded_rectangle((18, 24, 742, 742), radius=58, fill=(0, 0, 0, 180))
cshadow = cshadow.filter(ImageFilter.GaussianBlur(22))
img.alpha_composite(cshadow, (130, 140))

cdraw = ImageDraw.Draw(card)
cdraw.rounded_rectangle((0, 0, 760, 760), radius=58, fill=(11, 22, 36, 230), outline=(255, 255, 255, 45), width=2)

# Hero symbol plate
plate = Image.new("RGBA", (250, 250), (0, 0, 0, 0))
pdraw = ImageDraw.Draw(plate)
pdraw.rounded_rectangle((0, 0, 250, 250), radius=54, fill=(255, 255, 255, 22), outline=(255, 255, 255, 40), width=2)
pdraw.rounded_rectangle((24, 24, 226, 226), radius=42, fill=(225, 52, 64, 230))
pdraw.rectangle((82, 90, 168, 154), fill=(255, 255, 255, 245))
pdraw.rectangle((138, 102, 152, 166), fill=(225, 52, 64, 230))
pdraw.rectangle((70, 152, 180, 176), fill=(255, 255, 255, 245))

# Small sparkle
pdraw.ellipse((178, 54, 200, 76), fill=(255, 210, 120, 235))
pdraw.ellipse((192, 40, 202, 50), fill=(255, 255, 255, 235))

img.alpha_composite(card, (132, 132))
img.alpha_composite(plate, (387, 208))

# Typography
title_font = ImageFont.truetype(font_bold, 88)
subtitle_font = ImageFont.truetype(font_regular, 36)
pill_font = ImageFont.truetype(font_bold, 30)

draw = ImageDraw.Draw(img)
draw.text((182, 520), "Remove", font=title_font, fill=(245, 248, 255))
draw.text((182, 616), "Ads", font=title_font, fill=(245, 248, 255))
draw.text((182, 734), "Cleaner screens. Same EV tools.", font=subtitle_font, fill=(190, 202, 220))

# Feature pill
pill_text = "ONE-TIME PURCHASE"
pill_bbox = draw.textbbox((0, 0), pill_text, font=pill_font)
pw = pill_bbox[2] - pill_bbox[0] + 52
ph = pill_bbox[3] - pill_bbox[1] + 28
px, py = 182, 820
draw.rounded_rectangle((px, py, px + pw, py + ph), radius=ph // 2, fill=(225, 52, 64), outline=(255, 255, 255, 44), width=2)
draw.text((px + 26, py + 12), pill_text, font=pill_font, fill=(255, 255, 255))

# Bottom accent line
draw.rounded_rectangle((182, 932, 842, 944), radius=6, fill=(225, 52, 64))
draw.rounded_rectangle((610, 932, 842, 944), radius=6, fill=(71, 153, 255))

img = img.convert("RGB")
img.save(OUT, format="PNG")
print(OUT)
