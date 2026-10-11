"""Generates the package icon (imgs/dart_plex.png).

The same look as mpv_audio_kit's and mpv_studio's: one flat light-blue
glyph on a full navy disc. The glyph is the original mark's path, not a
redrawing: only scaled and centred. Run from the package
root (needs rsvg-convert):

    python3 tool/icon.py
"""
import os, subprocess, tempfile

NAVY = '#0D2A75'
LIGHT_BLUE = '#A8EDFA'
ICON = os.path.join('imgs', 'dart_plex.png')


# The chevron of Plex's own mark, exactly as the Simple Icons Plex logo
# draws it (the `x` of the wordmark in flumael/assets/icons/svg/plex.svg),
# in its 24-unit box: bbox x 16.752–21.39, y 8.623–15.29.
CHEVRON = 'M19.142 15.29h-2.39l2.247-3.332-2.247-3.335h2.39l2.248 3.335-2.248 3.332Z'
BBOX = (16.752, 8.623, 21.39, 15.29)
HEIGHT = 600  # on the 1024 canvas, as tall as mpv_audio_kit's bars


def icon_svg():
    """The Plex chevron, unaltered, scaled to [HEIGHT] and centred on a
    full navy disc."""
    x0, y0, x1, y1 = BBOX
    s = HEIGHT / (y1 - y0)
    tx, ty = 512 - s * (x0 + x1) / 2, 512 - s * (y0 + y1) / 2
    return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024" '
            'role="img" aria-label="dart_plex">\n'
            f'<circle cx="512" cy="512" r="512" fill="{NAVY}"/>\n'
            f'<path transform="translate({tx:.3f} {ty:.3f}) scale({s:.4f})" d="{CHEVRON}" fill="{LIGHT_BLUE}"/>\n'
            '</svg>\n')

if __name__ == '__main__':
    with tempfile.TemporaryDirectory() as tmp:
        svg = os.path.join(tmp, 'icon.svg')
        with open(svg, 'w') as fh:
            fh.write(icon_svg())
        subprocess.run(['rsvg-convert', svg, '-o', ICON], check=True)
    print(f'wrote {ICON}')
