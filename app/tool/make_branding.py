"""Builds the app's branding images from the two source logos.

Run from app/:  python tool/make_branding.py
Inputs:  assets/branding/logo_full.png, assets/branding/logo_text.png
Outputs: assets/branding/icon_foreground.png  elephant in the adaptive-icon safe zone
         assets/branding/logo_text_small.png  gold wordmark, transparent, for an app bar
         assets/branding/splash.png           full logo sized for the splash
"""

from PIL import Image, ImageFilter

BRANDING = "assets/branding/"


def cut_out(source):
    """The gold parts of [source] on a transparent background, cropped."""
    # Gold is red-heavy (red minus blue about 150); navy is blue-heavy
    # (about -100). The soft ramp between keeps edges smooth and keeps the
    # darker brushed streaks in the gold.
    mask = Image.new("L", source.size)
    px = source.load()
    w, h = source.size
    alpha = mask.load()
    for y in range(h):
        for x in range(w):
            pr, pg, pb = px[x, y]
            alpha[x, y] = max(0, min(255, int((pr - pb + 30) * 255 / 60)))
    mask = mask.filter(ImageFilter.GaussianBlur(0.8))
    cut = source.convert("RGBA")
    cut.putalpha(mask)
    return cut.crop(mask.getbbox())


def elephant_mark():
    mark = cut_out(Image.open(BRANDING + "logo_full.png").convert("RGB"))
    side = max(mark.size)
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    square.paste(mark, ((side - mark.width) // 2, (side - mark.height) // 2))
    return square


def icon_foreground(mark):
    # Adaptive icons show the middle 66%; keep the elephant inside ~58%.
    canvas = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    inner = mark.resize((600, 600), Image.LANCZOS)
    canvas.paste(inner, (212, 212), inner)
    canvas.save(BRANDING + "icon_foreground.png", optimize=True)


def logo_text_small():
    text = cut_out(Image.open(BRANDING + "logo_text.png").convert("RGB"))
    width = 900
    text.resize((width, round(text.height * width / text.width)), Image.LANCZOS).save(
        BRANDING + "logo_text_small.png", optimize=True
    )


def splash():
    full = Image.open(BRANDING + "logo_full.png").convert("RGB")
    full.resize((768, 768), Image.LANCZOS).save(BRANDING + "splash.png", optimize=True)


if __name__ == "__main__":
    icon_foreground(elephant_mark())
    logo_text_small()
    splash()
