#!/bin/bash
# regenerate .pngc (C header with embedded PNG data) from .png files
# Usage: bash macos/png2c.sh [include/images/*.png ...]
#   If no args given, rebuilds every .pngc for which the .png is newer.

set -euo pipefail

IMGDIR="$(cd "$(dirname "$0")/../include/images" && pwd)"

make_pngc() {
    local png="$1"
    local name; name="$(basename "$png" .png)"
    local safe; safe="$(echo "$name" | tr '.-' '__')"
    local guard; guard="$(echo "$name" | tr '.-' '__' | tr '[:lower:]' '[:upper:]')_PNG_H"

    local pngc="${png%.png}.pngc"

    # only rebuild if .png is newer than .pngc
    if [[ -f "$pngc" && "$png" -ot "$pngc" ]]; then
        return 0
    fi

    echo "  PNGC $pngc"

    # xxd -i output: first line declares the array, last line(s) declare the length.
    # We keep only the array body (including its closing }; ) and drop the _len line.
    local array_body
    array_body="$(xxd -i "$png" \
        | sed 's/^unsigned char .* = {/static const unsigned char '"$safe"'_png_data[] = {/' \
        | sed '$d')"

    cat > "$pngc" <<EOF
#ifndef ${guard}
#define ${guard}

${array_body}

#include "wx/mstream.h"

static wxImage *${safe}_png_img()
{
	if (!wxImage::FindHandler(wxT("PNG file")))
		wxImage::AddHandler(new wxPNGHandler());
	static wxImage *img_${safe}_png = new wxImage();
	if (!img_${safe}_png || !img_${safe}_png->IsOk())
	{
		wxMemoryInputStream img_${safe}_pngIS(${safe}_png_data, sizeof(${safe}_png_data));
		img_${safe}_png->LoadFile(img_${safe}_pngIS, wxBITMAP_TYPE_PNG);
	}
	return img_${safe}_png;
}
#define ${safe}_png_img ${safe}_png_img()

static wxBitmap *${safe}_png_bmp()
{
	static wxBitmap *bmp_${safe}_png;
	if (!bmp_${safe}_png || !bmp_${safe}_png->IsOk())
		bmp_${safe}_png = new wxBitmap(*${safe}_png_img);
	return bmp_${safe}_png;
}
#define ${safe}_png_bmp ${safe}_png_bmp()

static wxIcon *${safe}_png_ico()
{
	static wxIcon *ico_${safe}_png;
	if (!ico_${safe}_png || !ico_${safe}_png->IsOk())
	{
		ico_${safe}_png = new wxIcon();
		ico_${safe}_png->CopyFromBitmap(*${safe}_png_bmp);
	}
	return ico_${safe}_png;
}
#define ${safe}_png_ico ${safe}_png_ico()

#endif // ${guard}
EOF
}

if [[ $# -gt 0 ]]; then
    for f in "$@"; do
        make_pngc "$f"
    done
else
    # rebuild all .pngc files where the .png is newer, or the .pngc is missing
    for png in "$IMGDIR"/*.png; do
        pngc="${png%.png}.pngc"
        if [[ ! -f "$pngc" || "$png" -nt "$pngc" ]]; then
            make_pngc "$png"
        fi
    done
fi

echo "Done."
