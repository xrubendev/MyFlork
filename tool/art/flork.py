"""MyFlork illustrations, drawn as SVG.

Flork's shape, measured off the official drawing (flork_celular, head and body):
- the head is a dome that juts out on his right like a visor; its edge curls in at the jaw,
- his mouth is ONE long line from that jaw across the face, ending loose on the left; the head's grey shadow
  falls right under it,
- two small tilted dot eyes, the right one near the edge of the head,
- under the head the body is narrower on the right and widens to a flat bottom; the left side is one long curve
  with a grey shade inside,
- thin stick legs, thin arms and dark mitten hands with a thumb.
Everything is drawn in that drawing's own pixel space (the "ref" space below) so it can be checked against it.

Run: python tool/art/flork.py   (writes assets/art/svg/*.svg)
"""
from __future__ import annotations

import os

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "art", "svg")
INK = "#141016"
PAPER = "#fdfcfd"
SHADE = "#dad7dc"
MITT = "#2e2c2f"
PINK = "#ff3d8b"
GOLD = "#e0b23a"
PLUM = "#28212e"
W = 15  # outline width in ref space

P = tuple[float, float]


def smooth(pts: list[P], closed: bool = False) -> str:
    """Catmull-Rom through the points, as cubic Béziers."""
    n = len(pts)
    at = (lambda i: pts[i % n]) if closed else (lambda i: pts[max(0, min(n - 1, i))])
    d = f"M{pts[0][0]} {pts[0][1]}"
    for i in range(n if closed else n - 1):
        p0, p1, p2, p3 = at(i - 1), at(i), at(i + 1), at(i + 2)
        c1 = (p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6)
        c2 = (p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6)
        d += f" C{c1[0]:.1f} {c1[1]:.1f} {c2[0]:.1f} {c2[1]:.1f} {p2[0]} {p2[1]}"
    return d + (" Z" if closed else "")


def cont(pts: list[P]) -> str:
    """A smooth segment that continues a path (drops its leading M)."""
    return "L" + smooth(pts)[1:]


# ── Ref space: 0..860 wide, feet at ~1230 ───────────────────────────────────────────────────────────────────────
# Left side, bottom to top, then over the dome and down the head's right side to the jaw.
HEAD_L: list[P] = [(58, 1030), (44, 860), (52, 640), (88, 420), (150, 250), (240, 130), (350, 62), (470, 46),
                   (580, 64), (668, 132), (716, 220), (736, 290)]
JAW: list[P] = [(736, 290), (726, 322), (700, 344)]
# The body's right side, from just under the jaw down to the bottom.
BODY_R: list[P] = [(690, 352), (680, 420), (688, 540), (708, 700), (728, 860), (742, 970)]
BOTTOM: list[P] = [(742, 970), (600, 996), (400, 1016), (220, 1026), (58, 1030)]
MOUTH: list[P] = [(700, 344), (640, 352), (540, 358), (420, 362), (330, 364), (272, 366)]
SHADOW: list[P] = [(282, 372), (420, 370), (560, 365), (668, 356), (676, 378), (560, 398), (420, 408), (300, 414), (280, 398)]
SHADE_L: list[P] = [(62, 1026), (48, 860), (56, 640), (92, 420), (154, 252), (244, 132), (350, 66),
                    (290, 112), (230, 190), (186, 300), (160, 440), (152, 620), (162, 820), (186, 1020)]
EYE_L: P = (430, 302)
EYE_R: P = (682, 290)

BODY = smooth(HEAD_L) + " " + cont(JAW) + " " + cont(BODY_R) + " " + cont(BOTTOM) + " Z"
OUTLINE = smooth(HEAD_L + JAW[1:]) + " " + smooth(BODY_R) + " " + smooth(BOTTOM)


def mitt(x: float, y: float, rot: float = 0, s: float = 1) -> str:
    """Dark mitten with a thumb, palm centred on (x, y)."""
    return (f'<g transform="translate({x} {y}) rotate({rot}) scale({s})">'
            f'<path d="M-30 18 C-44 -6 -30 -30 -6 -34 C-2 -58 20 -66 28 -48 C34 -34 26 -22 22 -14 C40 -6 42 20 26 36 '
            f'C10 52 -22 46 -30 18 Z" fill="{MITT}" stroke="{INK}" stroke-width="{W - 2}"/></g>')


def arm(pts: list[P]) -> str:
    return f'<path d="{smooth(pts)}" fill="none" stroke="{INK}" stroke-width="{W - 3}"/>'


ARMS = {
    # Hand on his chin, the classic pose.
    "chin": ([(118, 760), (180, 900), (250, 990)], [(700, 760), (660, 690), (650, 600), (668, 540)], (668, 520, 10)),
    "down": ([(90, 640), (60, 760), (40, 880)], [(712, 640), (760, 760), (790, 880)], (796, 906, 0)),
    "wave": ([(90, 640), (60, 760), (40, 880)], [(712, 600), (800, 520), (860, 430), (880, 340)], (884, 316, -14)),
    "cheer": ([(80, 600), (20, 480), (-10, 360), (-14, 260)], [(712, 600), (800, 480), (840, 360), (846, 260)], (848, 236, 12)),
    "hold": ([(110, 640), (200, 700), (330, 720), (400, 708)], [(700, 620), (640, 690), (560, 716), (500, 712)], (494, 706, -70)),
    "tool": ([(90, 640), (60, 760), (40, 880)], [(706, 600), (742, 650), (772, 700)], (780, 712, -30)),
    "point": ([(90, 640), (60, 760), (40, 880)], [(712, 600), (820, 560), (920, 520), (990, 490)], (1000, 486, 60)),
    "eyes": ([(110, 640), (200, 560), (300, 440), (360, 360)], [(700, 600), (640, 500), (600, 420), (580, 360)], (580, 344, -20)),
}


# Props held in one hand at his side; the grip is the end of the "tool" arm.
SIDE_PROPS = {"wrench", "brush", "megaphone", "magnifier"}
GRIP = (780, 712)


def flork(x: float = 0, y: float = 0, s: float = 0.5, mood: str = "smile", arms: str = "down", flip: bool = False,
          hat: str | None = None, eyes: str | None = None, outfit: str | None = None, prop: str | None = None,
          rim: str | None = None) -> str:
    """One Flork in 3/4 view facing right (flip=True faces left). At s=1 he's 860 wide and ~1240 tall.
    `rim` adds a light edge behind his legs and arms so they read on dark scenes."""
    if prop in SIDE_PROPS:
        arms = "tool"
    left_arm, right_arm, right_hand = ARMS[arms]
    tf = f"translate({x + (860 * s if flip else 0)} {y}) scale({-s if flip else s} {s})"
    g = [
        f'<ellipse cx="400" cy="1228" rx="330" ry="30" fill="#000" opacity=".1"/>',
        # Legs and feet (with a light edge on dark scenes)
        (f'<path d="M292 1024 L290 1206 L250 1220 M546 1012 L548 1200 L592 1214" fill="none" stroke="{rim}" stroke-width="{W + 14}" opacity=".55"/>' if rim else ""),
        f'<path d="M292 1024 L290 1206 L250 1220 M546 1012 L548 1200 L592 1214" fill="none" stroke="{INK}" stroke-width="{W - 3}"/>',
        f'<path d="{BODY}" fill="{PAPER}"/>',
        f'<path d="{smooth(SHADE_L, closed=True)}" fill="{SHADE}"/>',
    ]
    if outfit:
        cid = f"b{abs(hash((x, y, s, outfit))) % 10**8}"
        g.append(f'<clipPath id="{cid}"><path d="{BODY}"/></clipPath><g clip-path="url(#{cid})">{_outfit(outfit)}</g>')
    g.append(f'<path d="{smooth(SHADOW, closed=True)}" fill="{SHADE}"/>')
    g.append(f'<path d="{OUTLINE}" fill="none" stroke="{INK}" stroke-width="{W}"/>')
    g.append(_face(mood))
    if eyes:
        g.append(_eyes(eyes))
    if hat:
        g.append(_hat(hat))
    if rim:
        for a in (left_arm, right_arm):
            g.append(f'<path d="{smooth(a)}" fill="none" stroke="{rim}" stroke-width="{W + 12}" opacity=".55"/>')
    g.append(arm(left_arm))
    g.append(arm(right_arm))
    if prop:
        g.append(_prop(prop))
    if not (arms == "hold" and prop) and prop not in SIDE_PROPS:
        hx, hy, hr = right_hand
        g.append(mitt(hx, hy, hr))
    if arms not in ("chin", "hold"):
        lx, ly = left_arm[-1]
        g.append(mitt(lx, ly + 18, -10))
    return f'<g transform="{tf}" stroke-linecap="round" stroke-linejoin="round">{"".join(g)}</g>'


def _face(mood: str) -> str:
    mouth = MOUTH
    if mood == "happy":  # the line lifts at both ends, like the middle Flork in "meet Flork"
        mouth = [(700, 344), (640, 362), (540, 372), (420, 372), (330, 362), (282, 340)]
    if mood == "sad":
        mouth = [(700, 344), (640, 350), (540, 352), (420, 360), (330, 374), (282, 392)]
    if mood == "happy":
        eyes = (f'<path d="M{EYE_L[0] - 22} {EYE_L[1] + 6} Q{EYE_L[0]} {EYE_L[1] - 16} {EYE_L[0] + 22} {EYE_L[1] + 6}" fill="none" stroke="{INK}" stroke-width="{W - 2}"/>'
                f'<path d="M{EYE_R[0] - 20} {EYE_R[1] + 6} Q{EYE_R[0]} {EYE_R[1] - 14} {EYE_R[0] + 18} {EYE_R[1] + 4}" fill="none" stroke="{INK}" stroke-width="{W - 2}"/>')
    else:
        eyes = (f'<ellipse cx="{EYE_L[0]}" cy="{EYE_L[1]}" rx="13" ry="19" transform="rotate(22 {EYE_L[0]} {EYE_L[1]})" fill="{INK}"/>'
                f'<ellipse cx="{EYE_R[0]}" cy="{EYE_R[1]}" rx="12" ry="18" transform="rotate(22 {EYE_R[0]} {EYE_R[1]})" fill="{INK}"/>')
    return f'{eyes}<path d="{smooth(mouth)}" fill="none" stroke="{INK}" stroke-width="{W}"/>'


def _hat(kind: str) -> str:
    # The dome runs from (150,250) over (470,46) to (716,220); hats sit on that line.
    if kind == "beanie":
        return '<g transform="translate(0 -64)">' + (f'<path d="M150 262 C190 110 330 30 470 30 C600 32 700 110 730 236 C560 200 330 206 150 262 Z" fill="{PINK}" stroke="{INK}" stroke-width="{W}"/>'
                f'<path d="M140 270 C330 214 560 206 740 244 L748 304 C560 268 330 274 150 336 Z" fill="#ff7aaf" stroke="{INK}" stroke-width="{W}"/>'
                + "".join(f'<path d="M{180 + i * 42} {300 - i * 4} L{182 + i * 42} {262 - i * 4}" stroke="{INK}" stroke-width="5" opacity=".3"/>' for i in range(13))
                + f'<circle cx="470" cy="22" r="40" fill="#ff7aaf" stroke="{INK}" stroke-width="{W}"/>') + '</g>'
    if kind == "cap":
        return '<g transform="translate(0 -40)">' + (f'<path d="M150 262 C200 100 360 36 480 40 C610 46 700 120 722 230 C540 200 330 208 150 262 Z" fill="#3d2bd6" stroke="{INK}" stroke-width="{W}"/>'
                f'<path d="M640 214 C740 196 860 206 900 236 C820 262 720 262 650 250 Z" fill="#2a1da3" stroke="{INK}" stroke-width="{W}"/>'
                f'<path d="M270 150 C330 96 420 74 470 76" fill="none" stroke="#6b5cff" stroke-width="18" opacity=".7"/>') + '</g>'
    if kind == "crown":
        return (f'<path d="M260 150 L282 20 L370 104 L470 -10 L560 98 L650 30 L668 160 C540 128 390 128 260 150 Z" fill="{GOLD}" stroke="{INK}" stroke-width="{W}"/>'
                f'<circle cx="470" cy="-10" r="18" fill="{PINK}" stroke="{INK}" stroke-width="9"/>')
    if kind == "santa":
        return '<g transform="translate(0 -64)">' + (f'<path d="M150 262 C200 100 360 30 520 40 C650 50 760 140 800 300 C760 250 720 230 700 226 C540 200 330 208 150 262 Z" fill="#e5383b" stroke="{INK}" stroke-width="{W}"/>'
                f'<path d="M140 270 C330 214 560 206 740 244 L748 304 C560 268 330 274 150 336 Z" fill="#fff" stroke="{INK}" stroke-width="{W}"/>'
                f'<circle cx="808" cy="320" r="38" fill="#fff" stroke="{INK}" stroke-width="{W}"/>') + '</g>'
    if kind == "hardhat":
        return (f'<path d="M170 250 C190 90 330 30 470 30 C620 34 720 110 738 236 Z" fill="#f2a516" stroke="{INK}" stroke-width="{W}"/>'
                f'<path d="M110 262 C330 214 560 206 800 236 L796 276 C560 248 330 256 116 302 Z" fill="#f2a516" stroke="{INK}" stroke-width="{W}"/>'
                f'<path d="M470 34 L470 220" stroke="{INK}" stroke-width="10"/><path d="M300 70 C330 120 340 170 344 226" fill="none" stroke="#ffd166" stroke-width="16" opacity=".8"/>')
    if kind == "beret":
        return (f'<path d="M180 240 C140 170 260 60 470 52 C680 48 790 150 720 230 C560 196 360 196 180 240 Z" fill="#2fbf71" stroke="{INK}" stroke-width="{W}"/>'
                f'<path d="M470 52 L480 12" stroke="{INK}" stroke-width="14"/>')
    if kind == "headset":
        return (f'<path d="M190 330 C200 120 640 60 720 290" fill="none" stroke="{INK}" stroke-width="26"/>'
                f'<rect x="150" y="300" width="70" height="110" rx="28" fill="{PLUM}" stroke="{INK}" stroke-width="{W - 2}"/>'
                f'<rect x="690" y="262" width="66" height="104" rx="26" fill="{PLUM}" stroke="{INK}" stroke-width="{W - 2}"/>'
                f'<path d="M190 408 C190 470 260 480 320 470" fill="none" stroke="{INK}" stroke-width="9"/><circle cx="328" cy="470" r="16" fill="{PINK}" stroke="{INK}" stroke-width="8"/>')
    return ""


def _eyes(kind: str) -> str:
    l, r = EYE_L, EYE_R
    if kind == "shades":
        return (f'<path d="M{l[0] - 70} {l[1] - 34} L{l[0] + 58} {l[1] - 44} L{l[0] + 44} {l[1] + 34} L{l[0] - 52} {l[1] + 40} Z" fill="{INK}"/>'
                f'<path d="M{r[0] - 70} {r[1] - 30} L{r[0] + 42} {r[1] - 40} L{r[0] + 30} {r[1] + 32} L{r[0] - 54} {r[1] + 38} Z" fill="{INK}"/>'
                f'<path d="M{l[0] + 56} {l[1] - 20} L{r[0] - 68} {r[1] - 12}" stroke="{INK}" stroke-width="12"/>'
                f'<path d="M{l[0] - 40} {l[1] - 18} L{l[0] + 6} {l[1] - 24}" stroke="#fff" stroke-width="8" opacity=".45"/>')
    if kind == "3d":
        return (f'<path d="M{l[0] - 80} {l[1] - 44} L{l[0] + 64} {l[1] - 54} L{l[0] + 50} {l[1] + 44} L{l[0] - 62} {l[1] + 50} Z" fill="#c8323a" stroke="{INK}" stroke-width="{W - 2}"/>'
                f'<path d="M{r[0] - 76} {r[1] - 40} L{r[0] + 54} {r[1] - 50} L{r[0] + 40} {r[1] + 42} L{r[0] - 60} {r[1] + 48} Z" fill="#2f6fd6" stroke="{INK}" stroke-width="{W - 2}"/>'
                f'<path d="M{l[0] - 52} {l[1] - 22} L{l[0] + 40} {l[1] - 28} L{l[0] + 30} {l[1] + 28} L{l[0] - 40} {l[1] + 32} Z" fill="{INK}" opacity=".85"/>'
                f'<path d="M{r[0] - 50} {r[1] - 20} L{r[0] + 32} {r[1] - 26} L{r[0] + 24} {r[1] + 26} L{r[0] - 40} {r[1] + 30} Z" fill="{INK}" opacity=".85"/>')
    if kind == "goggles":
        return (f'<path d="M120 300 C300 284 560 270 760 262" stroke="{INK}" stroke-width="24" fill="none"/>'
                f'<circle cx="{l[0]}" cy="{l[1]}" r="58" fill="#7b4a35" stroke="{INK}" stroke-width="{W - 2}"/><circle cx="{l[0]}" cy="{l[1]}" r="34" fill="{PINK}" stroke="{INK}" stroke-width="9"/>'
                f'<circle cx="{r[0] - 8}" cy="{r[1]}" r="54" fill="#7b4a35" stroke="{INK}" stroke-width="{W - 2}"/><circle cx="{r[0] - 8}" cy="{r[1]}" r="31" fill="{PINK}" stroke="{INK}" stroke-width="9"/>'
                f'<circle cx="{l[0] - 12}" cy="{l[1] - 14}" r="9" fill="#fff" opacity=".8"/><circle cx="{r[0] - 20}" cy="{r[1] - 14}" r="9" fill="#fff" opacity=".8"/>')
    return ""


def _outfit(kind: str) -> str:
    # The body below the shadow: from y ~460 down to the bottom edge.
    clip = "M0 460 L860 440 L860 1100 L0 1100 Z"
    if kind == "hoodie":
        return (f'<path d="{clip}" fill="{PLUM}"/>'
                f'<path d="M330 476 L336 560 M520 470 L514 552" stroke="#fff" stroke-width="10"/>'
                f'<rect x="300" y="700" width="260" height="120" rx="26" fill="#3a2f42"/>')
    if kind == "tee":
        return (f'<path d="{clip}" fill="{PINK}"/>'
                f'<text x="400" y="720" font-family="Arial Black,Arial" font-weight="900" font-size="104" text-anchor="middle" fill="#fff">FLORK</text>')
    return ""


def _prop(kind: str) -> str:
    hands = mitt(400, 716, 70) + mitt(500, 718, -70)
    if kind == "phone":
        return (f'<rect x="372" y="560" width="150" height="250" rx="28" fill="#1d3a6b" stroke="{INK}" stroke-width="{W - 2}"/>'
                f'<rect x="392" y="586" width="110" height="186" rx="12" fill="#3f7fe0"/>{hands}')
    if kind == "coin":
        return (f'<circle cx="450" cy="640" r="104" fill="{GOLD}" stroke="{INK}" stroke-width="{W}"/>'
                f'<circle cx="450" cy="640" r="72" fill="none" stroke="#8a5a00" stroke-width="10"/>'
                f'<text x="450" y="676" font-family="Arial Black,Arial" font-weight="900" font-size="96" text-anchor="middle" fill="#8a5a00">F</text>{hands}')
    if kind == "map":
        return (f'<path d="M270 560 L620 534 L644 790 L290 816 Z" fill="#f4e3b5" stroke="{INK}" stroke-width="{W - 2}"/>'
                f'<path d="M320 620 C400 580 470 700 560 640" fill="none" stroke="{PINK}" stroke-width="10" stroke-dasharray="22 18"/>'
                f'<path d="M548 612 L590 654 M590 612 L548 654" stroke="#c8323a" stroke-width="13"/>{mitt(300, 700, 70)}{mitt(630, 680, -70)}')
    if kind == "bag":
        return (f'<path d="M330 600 C330 520 560 520 560 600 L590 820 C450 856 320 850 300 820 Z" fill="#6b4a2a" stroke="{INK}" stroke-width="{W}"/>'
                f'<path d="M370 590 C370 520 520 520 520 590" fill="none" stroke="{INK}" stroke-width="13"/>'
                f'<text x="444" y="770" font-family="Arial Black,Arial" font-weight="900" font-size="110" text-anchor="middle" fill="{GOLD}">$</text>{hands}')
    if kind == "binoculars":
        return (f'<g transform="translate(470 330)"><rect x="-120" y="-50" width="100" height="120" rx="30" fill="{PLUM}" stroke="{INK}" stroke-width="{W}"/>'
                f'<rect x="20" y="-56" width="100" height="120" rx="30" fill="{PLUM}" stroke="{INK}" stroke-width="{W}"/>'
                f'<rect x="-30" y="-14" width="60" height="40" fill="{PLUM}" stroke="{INK}" stroke-width="10"/>'
                f'<circle cx="-70" cy="-44" r="34" fill="#7fe3ff" stroke="{INK}" stroke-width="10"/><circle cx="70" cy="-50" r="34" fill="#7fe3ff" stroke="{INK}" stroke-width="10"/></g>'
                f'{mitt(372, 380, 20)}{mitt(572, 372, -20)}')
    gx, gy = GRIP
    if kind == "megaphone":
        return (f'<g transform="translate({gx} {gy}) rotate(-72)">'
                f'<rect x="-20" y="-36" width="60" height="72" rx="14" fill="#c8323a" stroke="{INK}" stroke-width="{W - 2}"/>'
                f'<path d="M36 -40 L190 -110 L190 110 L36 40 Z" fill="#ffd166" stroke="{INK}" stroke-width="{W}"/>'
                f'<path d="M220 -90 L270 -120 M228 0 L290 0 M220 90 L270 120" stroke="{INK}" stroke-width="12"/></g>'
                f'{mitt(gx, gy, -30)}')
    if kind == "brush":
        return (f'<path d="M{gx} {gy} L{gx + 120} {gy - 330}" stroke="#8a5a2b" stroke-width="26"/>'
                f'<path d="M{gx + 110} {gy - 320} L{gx + 132} {gy - 380} C{gx + 146} {gy - 412} {gx + 176} {gy - 398} {gx + 164} {gy - 366} L{gx + 140} {gy - 306} Z" fill="{PINK}" stroke="{INK}" stroke-width="{W - 3}"/>'
                f'{mitt(gx, gy, -30)}')
    if kind == "wrench":
        return (f'<path d="M{gx} {gy} L{gx + 110} {gy - 270}" stroke="#9aa3ad" stroke-width="34"/>'
                f'<g transform="translate({gx + 118} {gy - 300}) rotate(22)"><path d="M-46 30 C-60 -24 -20 -66 20 -60 L6 -20 L34 -6 L52 -40 C80 0 54 60 0 58 Z" fill="#9aa3ad" stroke="{INK}" stroke-width="{W - 3}"/></g>'
                f'{mitt(gx, gy, -30)}')
    if kind == "magnifier":
        return (f'<path d="M{gx} {gy} L{gx + 70} {gy - 170}" stroke="#8a5a2b" stroke-width="30"/>'
                f'<circle cx="{gx + 100}" cy="{gy - 250}" r="86" fill="#cdeffd" fill-opacity=".55" stroke="{INK}" stroke-width="{W + 3}"/>'
                f'<path d="M{gx + 50} {gy - 280} C{gx + 60} {gy - 310} {gx + 80} {gy - 320} {gx + 100} {gy - 326}" stroke="#fff" stroke-width="12" fill="none"/>'
                f'{mitt(gx, gy, -30)}')
    return ""


def svg(w: int, h: int, body: str, bg: str | None = None) -> str:
    fill = f'<rect width="{w}" height="{h}" fill="{bg}"/>' if bg else ""
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" width="{w}" height="{h}">{fill}{body}</svg>'


def write(name: str, content: str) -> None:
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, f"{name}.svg"), "w", encoding="utf-8") as f:
        f.write(content)
    print(name)


if __name__ == "__main__":
    looks = [
        ("smile", "down", None, None, None, None),
        ("happy", "cheer", "beanie", None, None, None),
        ("smile", "hold", "cap", "shades", "hoodie", "phone"),
        ("happy", "hold", "crown", "3d", "tee", "coin"),
        ("smile", "hold", "headset", "goggles", None, "map"),
    ]
    s = 0.4
    row = "".join(flork(40 + i * 400, 60, s, mood=m, arms=a, hat=h, eyes=e, outfit=o, prop=p) for i, (m, a, h, e, o, p) in enumerate(looks))
    write("_sheet", svg(2040, 600, row, bg="#f6f0f8"))
