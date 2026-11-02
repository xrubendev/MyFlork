"""MyFlork scenes built from the Flork kit in flork.py. Run: python tool/art/scenes.py"""
from __future__ import annotations

import math
import random

from flork import GOLD, INK, PINK, PLUM, W, flork, mitt, svg, write

rnd = random.Random(7)


def night(w: int, h: int, horizon: float) -> str:
    """Plum night sky with stars, a big moon and a neon city on the horizon."""
    stars = "".join(f'<circle cx="{rnd.uniform(0, w):.0f}" cy="{rnd.uniform(0, horizon * .8):.0f}" r="{rnd.choice([1.4, 2, 2.6])}" fill="#fff" opacity="{rnd.uniform(.35, .9):.2f}"/>' for _ in range(90))
    city = []
    x = -20
    while x < w + 20:
        bw = rnd.randint(70, 150)
        bh = rnd.randint(int(h * .14), int(h * .34))
        top = horizon - bh
        city.append(f'<rect x="{x}" y="{top}" width="{bw}" height="{bh + 40}" fill="#1c1322"/>')
        for wy in range(int(top) + 18, int(horizon) - 10, 26):
            for wx in range(x + 12, x + bw - 14, 22):
                if rnd.random() < .32:
                    c = rnd.choice([PINK, "#7fe3ff", "#ffd166"])
                    city.append(f'<rect x="{wx}" y="{wy}" width="9" height="12" fill="{c}" opacity="{rnd.uniform(.5, .95):.2f}"/>')
        if rnd.random() < .3:
            city.append(f'<rect x="{x + bw / 2 - 2}" y="{top - 40}" width="4" height="40" fill="#1c1322"/><circle cx="{x + bw / 2}" cy="{top - 42}" r="5" fill="{PINK}"/>')
        x += bw + rnd.randint(-10, 14)
    return (
        f'<defs><linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#140a18"/><stop offset=".6" stop-color="#3a1532"/><stop offset="1" stop-color="#5a1a40"/></linearGradient>'
        f'<radialGradient id="moonglow"><stop offset="0" stop-color="#ffe9f2" stop-opacity=".55"/><stop offset="1" stop-color="#ffe9f2" stop-opacity="0"/></radialGradient></defs>'
        f'<rect width="{w}" height="{h}" fill="url(#sky)"/>{stars}'
        f'<circle cx="{w * .78}" cy="{h * .24}" r="{h * .26}" fill="url(#moonglow)"/>'
        f'<circle cx="{w * .78}" cy="{h * .24}" r="{h * .13}" fill="#fff6e8" stroke="{INK}" stroke-width="6"/>'
        f'<circle cx="{w * .76}" cy="{h * .21}" r="{h * .022}" fill="#efe0cc"/><circle cx="{w * .81}" cy="{h * .28}" r="{h * .016}" fill="#efe0cc"/>'
        + "".join(city)
        + f'<rect x="0" y="{horizon - 4}" width="{w}" height="6" fill="{PINK}" opacity=".35"/>'
    )


def quests_hero() -> None:
    """Three Florks on a rooftop at night, planning the next quest. 1600x900, room on the left for a title."""
    w, h = 1600, 900
    ground = 760
    roof = (f'<path d="M0 {ground} L{w} {ground - 10} L{w} {h} L0 {h} Z" fill="#241826"/>'
            f'<path d="M0 {ground} L{w} {ground - 10}" stroke="{INK}" stroke-width="10"/>'
            + "".join(f'<path d="M{x} {ground - 4} L{x - 30} {h}" stroke="#2f2132" stroke-width="6"/>' for x in range(80, w, 140))
            + f'<rect x="1040" y="{ground - 110}" width="140" height="100" rx="8" fill="#3a2a3e" stroke="{INK}" stroke-width="8"/>'
            f'<path d="M1060 {ground - 80} L1160 {ground - 80} M1060 {ground - 52} L1160 {ground - 52}" stroke="#1c1322" stroke-width="8"/>')
    rim = "#ffb3d1"
    crew = (flork(640, ground - 470, .38, mood="smile", arms="hold", hat="beanie", prop="map", rim=rim)
            + flork(900, ground - 500, .4, mood="happy", arms="hold", hat="cap", eyes="shades", outfit="hoodie", prop="bag", rim=rim)
            + flork(1230, ground - 450, .36, mood="smile", arms="eyes", hat="headset", prop="binoculars", flip=True, rim=rim))
    write("quests_hero", svg(w, h, night(w, h, ground - 30) + roof + crew))


def home_hero() -> None:
    """Phone cover for Home: same night, the crew grouped on the right, the left half free for the title. 1080x1000."""
    w, h = 1080, 1000
    ground = 900
    roof = (f'<path d="M0 {ground} L{w} {ground - 8} L{w} {h} L0 {h} Z" fill="#241826"/>'
            f'<path d="M0 {ground} L{w} {ground - 8}" stroke="{INK}" stroke-width="10"/>')
    rim = "#ffb3d1"
    crew = (flork(560, ground - 420, .34, mood="smile", arms="hold", hat="beanie", prop="map", rim=rim)
            + flork(770, ground - 440, .35, mood="happy", arms="hold", hat="cap", eyes="shades", outfit="hoodie", prop="bag", rim=rim))
    write("home_hero", svg(w, h, night(w, h, ground - 26) + roof + crew))


def crest(name: str, color: str, dark: str, **look) -> None:
    """A faction shield with a Flork bust inside."""
    w, h = 600, 680
    shield = "M300 30 C400 70 480 80 560 70 C570 300 520 520 300 650 C80 520 30 300 40 70 C120 80 200 70 300 30 Z"
    cid = f"c{name}"
    body = (f'<defs><linearGradient id="g{name}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{color}"/><stop offset="1" stop-color="{dark}"/></linearGradient>'
            f'<clipPath id="{cid}"><path d="{shield}"/></clipPath></defs>'
            f'<path d="{shield}" fill="url(#g{name})" stroke="{INK}" stroke-width="16"/>'
            f'<g clip-path="url(#{cid})">'
            + "".join(f'<path d="M300 380 L{300 + 700 * math.cos(a):.0f} {380 + 700 * math.sin(a):.0f}" stroke="#fff" stroke-width="28" opacity=".08"/>' for a in [i * math.pi / 8 for i in range(16)])
            + flork(70, 160, .46, **look) + '</g>'
            f'<path d="{shield}" fill="none" stroke="{INK}" stroke-width="16"/>'
            f'<path d="M300 58 C390 92 460 100 532 94" fill="none" stroke="#fff" stroke-width="10" opacity=".35"/>')
    write(f"faction_{name}", svg(w, h, body))


def loot_box() -> None:
    """A treasure chest bursting with light, a Flork peeking out of it."""
    w, h = 900, 760
    rays = "".join(f'<path d="M450 360 L{450 + 900 * math.cos(a):.0f} {360 + 900 * math.sin(a):.0f} L{450 + 900 * math.cos(a + .12):.0f} {360 + 900 * math.sin(a + .12):.0f} Z" fill="{GOLD}" opacity=".18"/>' for a in [i * math.pi / 9 for i in range(18)])
    chest = (f'<rect x="170" y="420" width="560" height="260" rx="26" fill="#8a5a2b" stroke="{INK}" stroke-width="16"/>'
             f'<rect x="170" y="420" width="560" height="60" fill="#6b4422" stroke="{INK}" stroke-width="16"/>'
             f'<path d="M260 420 L260 680 M640 420 L640 680" stroke="{GOLD}" stroke-width="26"/>'
             f'<rect x="400" y="470" width="100" height="110" rx="16" fill="{GOLD}" stroke="{INK}" stroke-width="12"/><circle cx="450" cy="518" r="16" fill="{INK}"/>')
    # Lid flung open, behind the Flork.
    lid = (f'<g transform="rotate(-24 170 420)"><path d="M170 420 C170 300 730 300 730 420 Z" fill="#9c6a35" stroke="{INK}" stroke-width="16"/>'
           f'<path d="M260 330 L260 420 M640 330 L640 420" stroke="{GOLD}" stroke-width="22"/></g>')
    coins = "".join(f'<circle cx="{x}" cy="{y}" r="{r}" fill="{GOLD}" stroke="{INK}" stroke-width="8"/>' for x, y, r in [(200, 300, 30), (700, 280, 34), (760, 380, 24), (140, 390, 22), (620, 190, 20), (300, 200, 18)])
    peek = flork(270, 90, .42, mood="happy", arms="cheer", hat="crown")
    body = f'<circle cx="450" cy="380" r="330" fill="{GOLD}" opacity=".12"/>{rays}{lid}{coins}{peek}{chest}'
    write("loot_box", svg(w, h, body))


def rewards_banner() -> None:
    w, h = 900, 600
    coins = "".join(f'<circle cx="{x}" cy="{y}" r="{r}" fill="{GOLD}" stroke="{INK}" stroke-width="8"/>' for x, y, r in [(120, 140, 30), (780, 120, 36), (820, 300, 22), (90, 360, 24), (700, 470, 20)])
    body = f'<circle cx="450" cy="320" r="270" fill="{PINK}" opacity=".18"/>{coins}' + flork(250, 40, .42, mood="happy", arms="hold", hat="crown", prop="bag")
    write("rewards_banner", svg(w, h, body))


def empty_search() -> None:
    write("empty_search", svg(760, 560, flork(90, 20, .42, mood="smile", prop="magnifier")))


if __name__ == "__main__":
    quests_hero()
    home_hero()
    crest("builders", "#ff7a3d", "#b8331a", mood="smile", hat="hardhat", prop="wrench")
    crest("signal", "#4aa3ff", "#1d4fb8", mood="happy", hat="headset", prop="megaphone")
    crest("doodle", "#3ddc84", "#1a8a4a", mood="smile", hat="beret", prop="brush")
    loot_box()
    rewards_banner()
    empty_search()
