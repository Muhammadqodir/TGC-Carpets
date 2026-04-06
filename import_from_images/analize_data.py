#!/usr/bin/env python3
"""
Parses all product images under:
    data/<quality>/<type>/<image>.jpg

For every image:
  1. Detects and crops the white info bar at the top.
  2. Reads the "ProductCode_Color" text from that bar via OCR
     (pytesseract).  Falls back to filename parsing when OCR is
     unavailable or returns nothing useful.
  3. Parses width, length (cm) and density from the filename.
  4. Saves the cropped carpet image to:
        processed_images/<quality>/<type>/<original_filename>
  5. Appends a product record to products.json.

Usage:
    pip install -r requirements.txt
    # Install Tesseract OCR engine: https://github.com/tesseract-ocr/tesseract
    python analize_data.py
"""

import json
import re
from pathlib import Path

import numpy as np
from PIL import Image

import pytesseract

_OCR_AVAILABLE = True


# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
BASE_DIR = Path(__file__).parent
DATA_DIR = BASE_DIR / "data"
OUTPUT_JSON = BASE_DIR / "products.json"
OUTPUT_IMAGES_DIR = BASE_DIR / "processed_images"

_IMAGE_SUFFIXES = {".jpg", ".jpeg", ".png", ".webp"}

# ---------------------------------------------------------------------------
# White-bar detection
# ---------------------------------------------------------------------------

def detect_info_bar_height(img: Image.Image) -> int:
    """
    Return the pixel height of the white info bar at the top of *img*.

    Strategy — uses the row *median* brightness:
    - The info bar is white with dark italic text.  Even in text rows the
      majority of pixels are pure white (255), so the median stays at 255
      throughout the entire bar despite anti-aliasing artifacts.
    - The carpet design always has mid-tone pixels (gray borders, patterns),
      so the median drops well below 255 the moment the design begins.
    - We stop at the first row whose median brightness < 220.
    - Returns 0 if no such transition is found (no info bar in image).
    """
    gray = np.asarray(img.convert("L"), dtype=np.uint8)

    for row_idx, row in enumerate(gray):
        if int(np.median(row)) < 220:
            return row_idx

    return 0


# ---------------------------------------------------------------------------
# OCR
# ---------------------------------------------------------------------------

def _read_bar_text(img: Image.Image, bar_height: int) -> str:
    """Extract text from the white info bar using Tesseract OCR."""
    if not _OCR_AVAILABLE or bar_height < 5:
        return ""

    bar_crop = img.crop((0, 0, img.width, bar_height))
    # Up-scale 3× for better OCR accuracy on small bars
    scale = 3
    bar_crop = bar_crop.resize(
        (bar_crop.width * scale, bar_crop.height * scale),
        Image.LANCZOS,
    )
    # PSM 7: treat image as a single text line
    config = r"--psm 7 -c tessedit_char_whitelist=ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-"
    raw = pytesseract.image_to_string(bar_crop, config=config)
    return raw.strip()


def _parse_ocr_text(text: str) -> tuple[str, str]:
    """
    Parse 'ProductCode_Color' from OCR output.
    Returns (product_name, color) or ("", "") on failure.
    """
    # Collapse any whitespace/noise around the separator
    cleaned = re.sub(r"[^\w\-]", "", text).strip("_-")
    match = re.match(r"^([A-Za-z0-9]+)[_-](.+)$", cleaned)
    if match:
        return match.group(1), match.group(2).lower()
    if cleaned:
        return cleaned, ""
    return "", ""


# ---------------------------------------------------------------------------
# Filename parsing
# ---------------------------------------------------------------------------

def parse_filename(stem: str) -> dict:
    """
    Extract structured fields from an image filename stem.

    Known patterns (non-exhaustive):
      7100_400x2500_66k   → name=7100, w=400, l=2500, density=66, color=k
      7293_k              → name=7293, color=k
      7115                → name=7115
      G1043_400x3000_73k  → name=G1043, w=400, l=3000, density=73, color=k
      4001k               → name=4001, color=k  (no separator)
      4140_300x400_seriy10→ name=4140, w=300, l=400, density=10, color=seriy
    """
    result: dict = {
        "product_name": "",
        "width_cm": None,
        "length_cm": None,
        "density": None,
        "color": "",
    }

    parts = stem.split("_")
    result["product_name"] = parts[0].upper()

    for part in parts[1:]:
        part = part.strip()
        if not part:
            continue

        # Dimensions: 350x500 or 400X2500
        dim_match = re.fullmatch(r"(\d+)[xX](\d+)", part)
        if dim_match:
            result["width_cm"] = int(dim_match.group(1))
            result["length_cm"] = int(dim_match.group(2))
            continue

        # density+color: 66k, 73gold, 55seriy, 10krem
        dc_match = re.fullmatch(r"(\d+)([a-zA-Z].*)", part)
        if dc_match:
            result["density"] = int(dc_match.group(1))
            result["color"] = dc_match.group(2).lower().rstrip("0123456789bmp").strip()
            continue

        # color+density (reversed): k67, seriy10
        cd_match = re.fullmatch(r"([a-zA-Z]+)(\d+)", part)
        if cd_match:
            result["density"] = int(cd_match.group(2))
            result["color"] = cd_match.group(1).lower()
            continue

        # Pure color abbreviation: k, m, g, grey, bej, gold …
        if re.fullmatch(r"[a-zA-Z]+", part):
            result["color"] = part.lower()

    # Handle cases where product name itself has a color suffix with no underscore
    # e.g. "4001k" → name=4001, color=k
    name_with_color = re.fullmatch(r"([A-Za-z0-9]+?)([a-zA-Z]{1,6})$", result["product_name"])
    if name_with_color and not result["color"] and len(parts) == 1:
        result["product_name"] = name_with_color.group(1).upper()
        result["color"] = name_with_color.group(2).lower()

    return result


# ---------------------------------------------------------------------------
# Image processing
# ---------------------------------------------------------------------------

def crop_and_save(img: Image.Image, bar_height: int, out_path: Path) -> None:
    """Strip the info bar and save only the carpet design."""
    cropped = img.crop((0, bar_height, img.width, img.height))
    cropped.save(out_path, quality=95)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def process_all() -> None:
    OUTPUT_IMAGES_DIR.mkdir(parents=True, exist_ok=True)
    products: list[dict] = []
    errors: list[dict] = []

    for quality_dir in sorted(DATA_DIR.iterdir()):
        if not quality_dir.is_dir() or quality_dir.name.startswith("."):
            continue
        quality = quality_dir.name

        for type_dir in sorted(quality_dir.iterdir()):
            if not type_dir.is_dir() or type_dir.name.startswith("."):
                continue
            product_type = type_dir.name

            out_dir = OUTPUT_IMAGES_DIR / quality / product_type
            out_dir.mkdir(parents=True, exist_ok=True)

            image_files = sorted(
                f for f in type_dir.iterdir()
                if f.is_file() and f.suffix.lower() in _IMAGE_SUFFIXES
            )

            for img_file in image_files:
                try:
                    img = Image.open(img_file)
                    bar_height = detect_info_bar_height(img)

                    # --- Name & color: OCR first, filename as fallback ---
                    ocr_raw = _read_bar_text(img, bar_height)
                    fn_data = parse_filename(img_file.stem)

                    if ocr_raw:
                        ocr_name, ocr_color = _parse_ocr_text(ocr_raw)
                        product_name = ocr_name if ocr_name else fn_data["product_name"]
                        color = ocr_color if ocr_color else fn_data["color"]
                    else:
                        product_name = fn_data["product_name"]
                        color = fn_data["color"]

                    # --- Crop & save ---
                    out_path = out_dir / img_file.name
                    crop_and_save(img, bar_height, out_path)

                    record = {
                        "product_name": product_name,
                        "color": color,
                        "quality": quality,
                        "type": product_type,
                        "width_cm": fn_data["width_cm"],
                        "length_cm": fn_data["length_cm"],
                        "density": fn_data["density"],
                        "original_filename": img_file.name,
                        "processed_image_path": str(
                            out_path.relative_to(BASE_DIR)
                        ),
                        "raw_ocr_text": ocr_raw,
                    }
                    products.append(record)

                    status = "OCR" if ocr_raw else "fname"
                    print(
                        f"  OK [{status:5s}]  "
                        f"{quality}/{product_type}/{img_file.name}"
                        f"  →  {product_name}_{color}"
                        f"  bar={bar_height}px"
                    )

                except Exception as exc:
                    errors.append({"file": str(img_file), "error": str(exc)})
                    print(f"  ERR  {img_file.name}: {exc}")

    with open(OUTPUT_JSON, "w", encoding="utf-8") as fh:
        json.dump(products, fh, indent=2, ensure_ascii=False)

    print(f"\n{'=' * 60}")
    print(f"Processed : {len(products)} images")
    print(f"Errors    : {len(errors)}")
    print(f"JSON      : {OUTPUT_JSON}")
    print(f"Images    : {OUTPUT_IMAGES_DIR}")

    if errors:
        print("\nFailed files:")
        for err in errors:
            print(f"  {err['file']}  →  {err['error']}")


if __name__ == "__main__":
    process_all()
