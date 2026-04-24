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
import warnings
import platform
from pathlib import Path
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


def load_font_by_family(family: str, size: int):
    """
    Load a font by family name with OS-aware resolution.
    No warning unless everything fails.
    """
    system = platform.system()

    macos_fonts = {
        "default": "/System/Library/Fonts/Supplemental/Verdana.ttf",
        "arial": "/System/Library/Fonts/Supplemental/Arial.ttf",
        "verdana": "/System/Library/Fonts/Supplemental/Verdana.ttf",
        "trebuchet": "/System/Library/Fonts/Supplemental/Trebuchet MS.ttf",
        "helvetica": "/System/Library/Fonts/Helvetica.ttc",
    }

    try:
        if system == "Darwin":
            path = macos_fonts.get(family.lower(), macos_fonts["default"])
            if Path(path).exists():
                return ImageFont.truetype(path, size)
            raise OSError(f"Font file not found: {path}")

        # Linux / Windows
        return ImageFont.truetype(family, size)

    except Exception as e:
        if not getattr(load_font_by_family, "_warned", False):
            warnings.warn(
                f"⚠️  Could not load font '{family}'. "
                f"Falling back to default font. Reason: {e}"
            )
            load_font_by_family._warned = True

        return ImageFont.load_default()


def add_text_below(
    image: Image.Image,
    text: str,
    text_color: tuple,
    qr_margin_px: int,
    font_family: str = "default",
):
    """
    Add auto-scaled text below a QR code using the same quiet-zone margin.
    Text is scaled to visually match QR width.
    """
    qr_width, qr_height = image.size

    top_padding = qr_margin_px
    bottom_padding = qr_margin_px

    draw = ImageDraw.Draw(image)

    min_font_size = 12
    max_font_size = int(qr_width * 0.30)
    target_width_ratio = 0.90
    max_height_ratio = 0.20

    # ✅ Ensure font is always defined
    font_size = max_font_size
    font = load_font_by_family(font_family, font_size)

    while font_size >= min_font_size:
        font = load_font_by_family(font_family, font_size)

        bbox = draw.textbbox((0, 0), text, font=font)
        text_width = bbox[2] - bbox[0]
        text_height = bbox[3] - bbox[1]

        if (
            text_width <= qr_width * target_width_ratio
            and text_height <= qr_height * max_height_ratio
        ):
            break

        font_size -= 1

    # Final measurement
    bbox = draw.textbbox((0, 0), text, font=font)
    text_width = bbox[2] - bbox[0]
    text_height = bbox[3] - bbox[1]

    new_height = qr_height + top_padding + text_height + bottom_padding

    new_img = Image.new(
        "RGB",
        (qr_width, new_height),
        "white",
    )

    new_img.paste(image, (0, 0))

    draw = ImageDraw.Draw(new_img)

    draw.text(
        ((qr_width - text_width) // 2, qr_height + top_padding),
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

        # QR layout parameters
        box_size = 10
        border = 4
        qr_margin_px = box_size * border

        # Contrast safety check
        check_contrast(fill_rgb, back_rgb)

        qr = qrcode.QRCode(
            version=1,
            error_correction=qrcode.constants.ERROR_CORRECT_H,
            box_size=box_size,
            border=border,
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

        # Append text with margin-aware layout
        if text:
            img = add_text_below(
                image=img,
                text=text,
                text_color=fill_rgb,
                qr_margin_px=qr_margin_px,
            )

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
