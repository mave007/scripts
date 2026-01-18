#!/usr/bin/env python3

# Quick QR code generator
# Supports Colors in HEX, RGB or human readable formats for fill and background
# Can add optional text below the QR code
# Supports multiple QR modes

# Requirements
# pip install qrcode[pil]>=7.4.2 Pillow>=10.0.0

import sys
import argparse
import qrcode
from PIL import Image, ImageDraw, ImageFont, ImageColor

from qrcode.image.styledpil import StyledPilImage
from qrcode.image.styles.colormasks import SolidFillColorMask
from qrcode.image.styles.moduledrawers import (
    SquareModuleDrawer,
    CircleModuleDrawer,
    RoundedModuleDrawer,
    VerticalBarsDrawer,
    HorizontalBarsDrawer,
    GappedSquareModuleDrawer,
)

# Available module drawer styles
MODULE_DRAWERS = {
    "square": SquareModuleDrawer,
    "circle": CircleModuleDrawer,
    "rounded": RoundedModuleDrawer,
    "vertical_bars": VerticalBarsDrawer,
    "horizontal_bars": HorizontalBarsDrawer,
    "gapped_square": GappedSquareModuleDrawer,
}

def parse_color(value: str):
    """
    Parse a color value.
    Supported formats:
      - Named colors: blue, cyan, red, etc. (Pillow-supported)
      - RGB: R,G,B
      - HEX: #RRGGBB or RRGGBB
    Returns an (R, G, B) tuple.
    """
    value = value.strip()

    # 1) Try Pillow color names and hex handling
    try:
        return ImageColor.getrgb(value)
    except ValueError:
        pass

    # 2) Try raw HEX without '#'
    if len(value) == 6:
        try:
            return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))
        except ValueError:
            pass

    # 3) Try RGB format
    try:
        parts = value.split(",")
        if len(parts) != 3:
            raise ValueError

        rgb = tuple(int(p) for p in parts)
        if any(c < 0 or c > 255 for c in rgb):
            raise ValueError

        return rgb
    except ValueError:
        raise argparse.ArgumentTypeError(
            "Color must be a name (blue), RGB (R,G,B), or HEX (#RRGGBB)"
        )


def list_modes():
    print("Available QR module styles:\n")
    for name in MODULE_DRAWERS:
        print(f"  - {name}")
    sys.exit(0)



def add_text_below(image: Image.Image, text: str, text_color: tuple):
    """
    Add bold, width-dominant, auto-scaled text below a QR code.
    Text attempts to visually fill the QR width.
    Uses the same color used in the QR code fill    
    """
    qr_width, qr_height = image.size

    padding = int(qr_height * 0.06)
    min_font_size = 12
    max_font_size = int(qr_width * 0.25)   # Aggressive starting size
    target_width_ratio = 0.90              # Desired width usage
    max_height_ratio = 0.18                # Safety cap

    draw = ImageDraw.Draw(image)

    # Load font
    try:
        font_path = "DejaVuSans.ttf"
        font = ImageFont.truetype(font_path, max_font_size)
    except IOError:
        font = ImageFont.load_default()
        max_font_size = getattr(font, "size", 14)

    font_size = max_font_size

    # Shrink until width target AND height safety are satisfied
    while font_size >= min_font_size:
        try:
            font = ImageFont.truetype(font_path, font_size)
        except IOError:
            font = ImageFont.load_default()

        bbox = draw.textbbox((0, 0), text, font=font)
        text_width = bbox[2] - bbox[0]
        text_height = bbox[3] - bbox[1]

        width_ok = text_width <= qr_width * target_width_ratio
        height_ok = text_height <= qr_height * max_height_ratio

        if width_ok and height_ok:
            break

        font_size -= 1

    # Final metrics
    bbox = draw.textbbox((0, 0), text, font=font)
    text_width = bbox[2] - bbox[0]
    text_height = bbox[3] - bbox[1]

    new_height = qr_height + text_height + padding
    new_img = Image.new("RGB", (qr_width, new_height), "white")
    new_img.paste(image, (0, 0))

    draw = ImageDraw.Draw(new_img)
    draw.text(
        ((qr_width - text_width) // 2, qr_height + padding // 2),
        text,
        fill=text_color,
        font=font,
    )

    return new_img


def relative_luminance(rgb):
    """
    Calculate relative luminance of an RGB color.
    Formula per WCAG 2.0
    """
    def channel(c):
        c = c / 255.0
        return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4

    r, g, b = rgb
    return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)


def contrast_ratio(rgb1, rgb2):
    """
    Calculate contrast ratio between two RGB colors.
    """
    l1 = relative_luminance(rgb1)
    l2 = relative_luminance(rgb2)
    lighter = max(l1, l2)
    darker = min(l1, l2)
    return (lighter + 0.05) / (darker + 0.05)


def check_contrast(front, back, min_ratio=4.5):
    ratio = contrast_ratio(front, back)
    if ratio < min_ratio:
        print(
            f"⚠️  Warning: Low contrast ratio ({ratio:.2f}:1). "
            f"QR codes scan best at {min_ratio}:1 or higher.",
            file=sys.stderr,
        )



def generate_qr(url, fill_rgb, back_rgb, mode, text, output):
    try:
        drawer_class = MODULE_DRAWERS.get(mode)
        if not drawer_class:
            raise ValueError(f"Unknown mode '{mode}'. Use --list to see options.")
        
        # Print Warning if contrast is not good enough
        check_contrast(fill_rgb, back_rgb)

        qr = qrcode.QRCode(
            version=1,
            error_correction=qrcode.constants.ERROR_CORRECT_H,
            box_size=10,
            border=4,
        )

        qr.add_data(url)
        qr.make(fit=True)

        img = qr.make_image(
            image_factory=StyledPilImage,
            module_drawer=drawer_class(),
            color_mask=SolidFillColorMask(
                front_color=fill_rgb,
                back_color=back_rgb,
            ),
        ).convert("RGB")

        if text:
            img = add_text_below(img, text, fill_rgb)

        img.save(output)
        print(f"✅ QR code generated successfully: {output}")

    except Exception as e:
        print(f"❌ Error: {e}", file=sys.stderr)
        sys.exit(1)



def main():
    parser = argparse.ArgumentParser(description="Generate a styled QR code.")

    parser.add_argument("-u", "--url", help="URL to encode")
    parser.add_argument("-f", "--fill-color", type=parse_color, default=(0, 0, 0))
    parser.add_argument("-b", "--back-color", type=parse_color, default=(255, 255, 255))
    parser.add_argument("-m", "--mode", default="circle", help="QR style mode")
    parser.add_argument("-t", "--text", help="Optional text below the QR code")
    parser.add_argument("-o", "--output", default="qrcode.png")
    parser.add_argument("-l", "--list", action="store_true", help="List QR styles")

    args = parser.parse_args()

    if args.list:
        list_modes()

    if not args.url:
        parser.error("the following arguments are required: -u/--url")

    generate_qr(
        url=args.url,
        fill_rgb=args.fill_color,
        back_rgb=args.back_color,
        mode=args.mode,
        text=args.text,
        output=args.output,
    )


if __name__ == "__main__":
    main()
