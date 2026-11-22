"""Erzeugt alle App-Icons aus der Vorlage des Design Systems (Komponente AppIcon).

Weisses Haus unter der Dachlinie in limette, drei steigende Balken in
gruen-dunkel, auf dem Verlauf gruen-dunkel (unten links) zu gruen (oben
rechts). Masse im 1024er-Raster wie in der Vorlage und in
lib/shell/app_icon.dart.

    python tool/make_app_icons.py        (braucht Pillow)

Erzeugt:
  web/favicon.svg                 Favicon fuer moderne Browser (scharf)
  web/favicon.png                 32 px, Rueckfall
  web/icons/Icon-192.png, -512    PWA, gerundet wie die Vorlage
  web/icons/Icon-maskable-*.png   PWA Android, quadratisch randlos (Inhalt
                                  liegt in der sicheren Zone)
  web/icons/apple-touch-icon.png  180 px, quadratisch, ohne Transparenz
                                  (iOS rundet selbst)
  tool/icons/app_icon_1024.png    Vorlage, quadratisch ohne Rundung
"""
import math
import os

from PIL import Image, ImageChops, ImageDraw

GRUEN_DUNKEL = (0x4F, 0x7A, 0x19)
GRUEN = (0x8A, 0xBB, 0x3D)
LIMETTE = (0xC2, 0xD4, 0x2E)
WEISS = (255, 255, 255)
RADIUS = 229.1  # Rundung der Vorlage im 1024er-Raster (22 %)
SS = 4  # Supersampling fuer glatte Kanten

SVG = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">
<defs><clipPath id="r"><rect width="1024" height="1024" rx="229.1"/></clipPath>
<linearGradient id="g" x1="0" y1="1" x2="1" y2="0"><stop offset="0" stop-color="#4f7a19"/><stop offset="1" stop-color="#8abb3d"/></linearGradient></defs>
<g clip-path="url(#r)"><rect width="1024" height="1024" fill="url(#g)"/>
<path d="M262 780V520L512 300 762 520V780Z" fill="#fff"/>
<path d="M196 506 512 228 828 506" fill="none" stroke="#c2d42e" stroke-width="56" stroke-linejoin="miter"/>
<path d="M342 716V624Q342 606 360 606H404Q422 606 422 624V716Z" fill="#4f7a19"/>
<path d="M472 716V544Q472 526 490 526H534Q552 526 552 544V716Z" fill="#4f7a19"/>
<path d="M602 716V464Q602 446 620 446H664Q682 446 682 464V716Z" fill="#4f7a19"/>
</g></svg>
"""


def gradient(size):
    """Linearer Verlauf von unten links (gruen-dunkel) nach oben rechts (gruen)."""
    import numpy as np
    x = np.linspace(0, 1, size)[None, :]
    y = np.linspace(0, 1, size)[:, None]
    t = (x + (1 - y)) / 2
    a, b = np.array(GRUEN_DUNKEL, float), np.array(GRUEN, float)
    rgb = (a + (b - a) * t[..., None]).round().astype('uint8')
    return Image.fromarray(rgb)


def roof_polygon(w=56.0):
    """Umriss der Dachlinie (Strich 56, Gehrung, gerade Enden) als Polygon."""
    a, b, c = (196.0, 506.0), (512.0, 228.0), (828.0, 506.0)

    def norm(p, q):
        dx, dy = q[0] - p[0], q[1] - p[1]
        l = math.hypot(dx, dy)
        return (-dy / l * w / 2, dx / l * w / 2)

    def intersect(p1, d1, p2, d2):
        det = d1[0] * d2[1] - d1[1] * d2[0]
        t = ((p2[0] - p1[0]) * d2[1] - (p2[1] - p1[1]) * d2[0]) / det
        return (p1[0] + d1[0] * t, p1[1] + d1[1] * t)

    n1, n2 = norm(a, b), norm(b, c)
    d1, d2 = (b[0] - a[0], b[1] - a[1]), (c[0] - b[0], c[1] - b[1])
    pts = []
    for sign in (1, -1):
        a_off = (a[0] + sign * n1[0], a[1] + sign * n1[1])
        c_off = (c[0] + sign * n2[0], c[1] + sign * n2[1])
        b_off1 = (b[0] + sign * n1[0], b[1] + sign * n1[1])
        b_off2 = (b[0] + sign * n2[0], b[1] + sign * n2[1])
        miter = intersect(b_off1, d1, b_off2, d2)
        pts.append((a_off, miter, c_off))
    (a1, m1, c1), (a2, m2, c2) = pts
    return [a1, m1, c1, c2, m2, a2]


def render(size, rounded=True, background=None):
    big = size * SS
    s = big / 1024.0
    img = gradient(big).convert('RGBA')
    d = ImageDraw.Draw(img)
    sc = lambda pts: [(x * s, y * s) for x, y in pts]
    d.polygon(sc([(262, 780), (262, 520), (512, 300), (762, 520), (762, 780)]), fill=WEISS)
    d.polygon(sc(roof_polygon()), fill=LIMETTE)
    for left, top in ((342, 606), (472, 526), (602, 446)):
        d.rounded_rectangle([left * s, top * s, (left + 80) * s, (716 + 18) * s], radius=18 * s,
                            fill=GRUEN_DUNKEL)
    # Unterkante der Balken gerade: unteren gerundeten Teil uebermalen (weiss wie das Haus).
    for left, _ in ((342, 606), (472, 526), (602, 446)):
        d.rectangle([left * s, (716) * s, (left + 80) * s, (716 + 18) * s], fill=WEISS)
    if rounded:
        mask = Image.new('L', (big, big), 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, big - 1, big - 1], radius=RADIUS * s, fill=255)
        img.putalpha(ImageChops.multiply(img.getchannel('A'), mask))
    img = img.resize((size, size), Image.LANCZOS)
    if background is not None:
        bg = Image.new('RGB', img.size, background)
        bg.paste(img, mask=img.getchannel('A'))
        return bg
    return img


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    web = os.path.join(root, 'web')
    icons = os.path.join(web, 'icons')
    open(os.path.join(web, 'favicon.svg'), 'w', encoding='utf-8').write(SVG)
    render(32).save(os.path.join(web, 'favicon.png'), optimize=True)
    for n in (192, 512):
        render(n).save(os.path.join(icons, f'Icon-{n}.png'), optimize=True)
        render(n, rounded=False).convert('RGB').save(os.path.join(icons, f'Icon-maskable-{n}.png'),
                                                      optimize=True)
    render(180, rounded=False).convert('RGB').save(os.path.join(icons, 'apple-touch-icon.png'),
                                                   optimize=True)
    render(1024, rounded=False).convert('RGB').save(os.path.join(root, 'tool', 'icons', 'app_icon_1024.png'),
                                                    optimize=True)
    print('Icons erzeugt.')


if __name__ == '__main__':
    main()
