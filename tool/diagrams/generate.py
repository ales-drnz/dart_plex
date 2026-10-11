"""Generates the package icon (imgs/dart_plex.png) and the README
diagrams in imgs/diagrams, as PNG only, in the style of mpv_audio_kit's.

The branding is flat colors: the icon's navy plate with a white glyph, and
light blue for your code in the diagrams.
Library nodes take the navy and your code's nodes the light blue. The
PNGs are transparent, so they sit on the page's own ground: text inside a
node relies on the node's fill, and the free text, arrows and bands use mid
tones that read on white and on GitHub's dark ground alike. The SVGs are drawn in a temporary directory and
exported at 2x with rsvg-convert.

Run from the repository root: python3 tool/diagrams/generate.py
"""
import os, subprocess, tempfile

OUT = os.path.join('imgs', 'diagrams')
ICON = os.path.join('imgs', 'dart_plex.png')
NAVY = '#0D2A75'
LIGHT_BLUE = '#A8EDFA'
# The icon's glyph: white on the navy disc. The diagrams keep the light
# blue, which also reads on a light page, where white would vanish.
GLYPH = '#FFFFFF'
SANS = "Noto Sans, system-ui, -apple-system, Segoe UI, sans-serif"
MONO = "Noto Sans Mono, ui-monospace, SFMono-Regular, Menlo, monospace"

PAL = {
    # ink: text inside neutral nodes, on their own fill. label, muted, line,
    # main, fail and band sit on the page ground, light or dark.
    'light': dict(ink='#1F2328', label='#6B7689', muted='#6B7689', line='#7D8796', main='#2F6FD6',
                  fail='#D1392B', failSoft='#FDE3E0', neutral='#E6EBF3', band='#7D8796'),
}


def esc(t):
    return t.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')


class D:
    def __init__(self, name, w, h, theme, label):
        self.name, self.w, self.h, self.t, self.c = name, w, h, theme, PAL[theme]
        self.label = label
        self.body = []

    def add(self, s):
        self.body.append(s)

    def svg(self):
        c = self.c
        defs = f'''<defs>
{''.join(f'<marker id="m{n}" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="10" markerHeight="10" markerUnits="userSpaceOnUse" orient="auto-start-reverse"><path d="M0,0 L10,5 L0,10 z" fill="{col}"/></marker>' for n, col in (('main', c['main']), ('sec', c['line']), ('fail', c['fail'])))}
</defs>'''
        return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {self.w} {self.h}" width="{self.w}" height="{self.h}" '
                f'role="img" aria-label="{esc(self.label)}">\n{defs}\n' + '\n'.join(self.body) + '\n</svg>\n')

    # role: lib (navy), app (cyan), neutral, fail, ghost (dimmed text)
    def node(self, x, y, w, h, title, sub=None, role='lib', mono=True, r=None, sub2=None, size=15):
        c = self.c
        r = 10 if r is None else r
        if role == 'lib':
            fill, tc, sc, op = NAVY, '#FFFFFF', '#C9DBFF', 1
        elif role == 'app':
            fill, tc, sc, op = LIGHT_BLUE, NAVY, '#1D3F7E', 1
        elif role == 'fail':
            fill, tc, sc, op = c['failSoft'], '#B42318', '#59636E', 1
        elif role == 'ghost':
            fill, tc, sc, op = c['neutral'], '#59636E', '#59636E', 1
        else:
            fill, tc, sc, op = c['neutral'], c['ink'], '#59636E', 1
        self.add(f'<rect x="{x - w / 2}" y="{y - h / 2}" width="{w}" height="{h}" rx="{r}" fill="{fill}" fill-opacity="{op}"/>')
        lines = [s for s in (sub, sub2) if s]
        ty = y + 5 - 9 * len(lines)
        self.add(f'<text x="{x}" y="{ty}" text-anchor="middle" font-family="{MONO if mono else SANS}" font-size="{size}" font-weight="600" fill="{tc}">{esc(title)}</text>')
        for i, s in enumerate(lines):
            self.add(f'<text x="{x}" y="{ty + 19 + 16 * i}" text-anchor="middle" font-family="{SANS}" font-size="12" fill="{sc}">{esc(s)}</text>')

    def arrow(self, d, kind='main', dash=False, head=True, width=None):
        c = self.c
        col = {'main': c['main'], 'sec': c['line'], 'fail': c['fail']}[kind]
        w = width or (2.2 if kind == 'main' else 1.7)
        dsh = ' stroke-dasharray="5 5"' if dash else ''
        mk = f' marker-end="url(#m{kind})"' if head else ''
        self.add(f'<path d="{d}" fill="none" stroke="{col}" stroke-width="{w}"{dsh}{mk}/>')

    def text(self, x, y, t, anchor='middle', color='muted', size=12, mono=False, weight=400):
        col = self.c.get(color, color)
        self.add(f'<text x="{x}" y="{y}" text-anchor="{anchor}" font-family="{MONO if mono else SANS}" font-size="{size}" font-weight="{weight}" fill="{col}">{esc(t)}</text>')

    def band(self, x, y, w, h, title):
        self.add(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="14" fill="{self.c["band"]}" fill-opacity="0.12"/>')
        self.text(x + 16, y + 24, title, anchor='start', color='muted', size=12, weight=600)


def architecture(t):
    d = D('architecture', 900, 470, t, 'Architecture: your code, the client, the shared transport and the servers')
    d.band(20, 20, 860, 150, 'Your app, calling isolate')
    d.node(170, 105, 230, 64, 'Your code', 'widgets, services', role='app', mono=False)
    d.node(450, 105, 230, 64, 'PlexClient', 'one sub-API per domain', role='lib')
    d.node(730, 105, 230, 64, 'Typed models', 'each with its raw map', role='lib', mono=False)
    d.arrow('M285,105 L333,105'); d.text(310, 92, 'calls', size=11)
    d.arrow('M730,73 L730,55 L170,55 L170,71', kind='sec'); d.text(450, 43, 'answers', size=11)
    d.band(20, 200, 860, 110, 'Transport, the same in dart_plex and dart_jellyfin')
    d.node(170, 265, 230, 60, 'http.Client', 'dart:io, cupertino, cronet', role='neutral', mono=False)
    d.node(450, 265, 210, 60, 'PlexConnection', 'cancel token, retry policy', role='lib')
    d.node(730, 265, 230, 60, 'Parsing isolate', 'gunzip, JSON, models', role='lib', mono=False)
    d.arrow('M450,137 L450,233'); d.text(462, 190, 'requests', anchor='start', size=11)
    d.arrow('M345,265 L287,265'); d.text(316, 252, 'send', size=11)
    d.arrow('M555,265 L613,265'); d.text(584, 252, '50 KB+', size=11)
    d.arrow('M730,233 L730,139', kind='sec'); d.text(742, 190, 'models', anchor='start', size=11)
    d.text(450, 322, 'smaller answers are parsed in place', size=11)
    d.node(170, 400, 230, 56, 'Plex Media Server', 'your server', role='neutral', mono=False)
    d.arrow('M170,297 L170,370', kind='sec')
    d.node(450, 400, 230, 56, 'plex.tv', 'sign-in, server list', role='neutral', mono=False)
    d.arrow('M200,297 L200,335 L450,335 L450,370', kind='sec')
    return d


def client_lifecycle(t):
    d = D('client_lifecycle', 1150, 150, t, 'Client lifecycle')
    steps = [('PlexClient(...)', 'credentials, once', 'lib'), ('sign in, connect', 'token and server', 'app'), ('sub-APIs', 'library, playback, ...', 'app'), ('withCancelToken()', "a page's calls", 'app'), ('close()', 'releases the client', 'lib')]
    for i, (a, b, role) in enumerate(steps):
        x = 115 + i * 230
        d.node(x, 75, 190, 64, a, b, role=role, size=14)
        if i:
            d.arrow(f'M{x - 230 + 95},75 L{x - 97},75')
    return d

def sign_in_flow(t):
    d = D('sign_in_flow', 900, 300, t, 'Sign-in with a PIN, then the best connection to a server')
    d.band(20, 20, 680, 120, 'plex.tv')
    d.node(140, 85, 190, 60, 'createPin()', 'a 4-character code', role='lib')
    d.node(360, 85, 190, 60, 'plex.tv/link', 'the user enters it', role='neutral', mono=False)
    d.node(580, 85, 190, 60, 'pollPin(id:)', 'polled until authToken', role='lib')
    d.node(790, 85, 150, 60, 'setToken()', role='app')
    d.arrow('M235,85 L263,85'); d.arrow('M455,85 L483,85'); d.arrow('M675,85 L713,85')
    d.node(140, 235, 190, 60, 'fetchResources()', 'owned and shared servers', role='lib')
    d.node(470, 235, 330, 60, 'bestConnection()', 'local, then https, then direct, then relay', role='lib')
    d.node(790, 235, 150, 60, 'connect()', 'server and token', role='app', size=14)
    d.arrow('M790,117 L790,160 L140,160 L140,203', kind='sec')
    d.arrow('M235,235 L303,235'); d.arrow('M635,235 L713,235')
    return d


def play_reporting(t):
    d = D('play_reporting', 900, 300, t, 'Timeline reports over one track')
    x0, x1 = 120, 860
    d.add(f'<line x1="{x0}" y1="150" x2="{x1}" y2="150" stroke="{d.c["line"]}" stroke-width="2"/>')
    d.text(x0, 182, '0', size=11); d.text(x1, 182, 'duration', size=11); d.text((x0 + x1) / 2, 182, 'about half', size=11)
    d.add(f'<line x1="{(x0 + x1) / 2}" y1="60" x2="{(x0 + x1) / 2}" y2="160" stroke="{d.c["main"]}" stroke-width="1.5" stroke-dasharray="4 5"/>')
    d.text((x0 + x1) / 2 + 12, 70, 'the play counts', anchor='start', size=12, color='main', weight=600)
    reports = [(120, 'playing'), (230, 'playing'), (340, 'paused'), (420, 'playing'), (560, 'playing'), (700, 'playing'), (820, 'stopped')]
    for x, s in reports:
        col = d.c['main'] if s != 'paused' else d.c['line']
        d.add(f'<circle cx="{x}" cy="150" r="6" fill="{col}"/>')
        d.text(x, 128, s, mono=True, size=11, color='label')
    d.band(120, 205, 740, 70, '')
    d.text(490, 235, 'timeline(playState:, timeMs:, durationMs:) at each change and every 10 s', mono=True, size=12, color='label')
    d.text(490, 258, 'reports must follow real time and carry the real duration', size=12)
    return d


def audio_transcode(t):
    d = D('audio_transcode_sequence', 900, 440, t, 'An audio transcode: decision, play, ping, stop')
    cols = [(150, 'Your code', 'app'), (450, 'dart_plex', 'lib'), (750, 'PMS', 'neutral')]
    for x, n, role in cols:
        d.node(x, 45, 170, 50, n, role=role, mono=False)
        d.add(f'<line x1="{x}" y1="72" x2="{x}" y2="425" stroke="{d.c["line"]}" stroke-width="1.2" stroke-dasharray="4 5"/>')
    steps = [(150, 450, 105, 'startAudioTranscode(...)', 'main'), (450, 750, 145, 'decision', 'sec'),
             (750, 450, 185, 'playable, profile', 'sec'), (450, 150, 225, 'url, session', 'sec'),
             (150, 750, 265, 'the player opens url', 'main'),
             (150, 450, 305, 'pingUniversal(session:)', 'main'), (450, 750, 330, 'while paused', 'sec'),
             (150, 450, 370, 'stopUniversal(session:)', 'main'), (450, 750, 395, 'a 404 is fine: gone', 'sec')]
    for a, b, y, label, kind in steps:
        d.arrow(f'M{a},{y} L{b + (8 if b < a else -8)},{y}', kind=kind)
        # The lifeline of the middle column crosses a label that spans the
        # whole width: centre that one between the first two columns.
        lx = (a + b) / 2 if abs(b - a) < 600 else (cols[0][0] + cols[1][0]) / 2
        d.text(lx, y - 12, label, mono='(' in label, color='label', size=12)
    return d


def events(t):
    d = D('events', 900, 320, t, 'Notification frames decoded into typed events')
    d.node(180, 60, 280, 60, 'connectWebSocket()', 'or connectEventSource()', role='lib')
    d.node(560, 60, 260, 60, 'PlexNotification', 'one frame, raw', role='lib')
    d.arrow('M320,60 L428,60'); d.text(374, 47, 'frames', size=11)
    items = [(100, 'PlexPlaySessionEvent', 'play states', 'lib'), (280, 'PlexLibraryItemEvent', 'added, changed, deleted', 'lib'),
             (460, 'PlexActivityEvent', 'scans, refreshes', 'lib'), (640, 'PlexStatusEvent', 'server status', 'lib'),
             (815, 'PlexUnknownEvent', 'anything else', 'ghost')]
    for x, a, b, role in items:
        d.node(x, 215, 168, 64, a, b, role=role, size=12)
        d.arrow(f'M560,92 L560,140 L{x},140 L{x},181', kind='main' if role == 'lib' else 'sec')
    d.text(572, 125, 'events()', anchor='start', mono=True, size=12, color='label')
    d.text(450, 290, 'switch over the sealed PlexEvent', size=12)
    return d


def icon_svg():
    """The package icon: the Plex chevron, the original mark's path only
    scaled and centred, in light blue on a full navy disc."""
    chevron = 'M19.142 15.29h-2.39l2.247-3.332-2.247-3.335h2.39l2.248 3.335-2.248 3.332Z'
    x0, y0, x1, y1 = 16.752, 8.623, 21.39, 15.29  # its exact bounding box
    s = 600 / (y1 - y0)  # as tall as mpv_audio_kit's bars
    # The inner vertex (the corner in the middle of its left side) sits on
    # the disc's centre. Neither geometric centre reads as centred for this
    # shape: on its box (the centroid) it looked left-heavy, on its
    # enclosing circle (the thin tip counted like a full corner) right-heavy.
    vx, vy = 18.999, 11.958  # M19.142,15.29 h-2.39 l2.247,-3.332
    tx, ty = 512 - s * vx, 512 - s * vy
    return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024" '
            'role="img" aria-label="dart_plex">\n'
            f'<circle cx="512" cy="512" r="512" fill="{NAVY}"/>\n'
            f'<path transform="translate({tx:.3f} {ty:.3f}) scale({s:.4f})" d="{chevron}" fill="{GLYPH}"/>\n</svg>\n')


ALL = [architecture, client_lifecycle, sign_in_flow, play_reporting, audio_transcode, events]

os.makedirs(OUT, exist_ok=True)
with tempfile.TemporaryDirectory() as tmp:
    for f in ALL:
        d = f('light')
        svg = os.path.join(tmp, f'{d.name}.svg')
        with open(svg, 'w') as fh:
            fh.write(d.svg())
        png = os.path.join(OUT, f'{d.name}.png')
        subprocess.run(['rsvg-convert', '-z', '2', svg, '-o', png], check=True)
    svg = os.path.join(tmp, 'icon.svg')
    with open(svg, 'w') as fh:
        fh.write(icon_svg())
    subprocess.run(['rsvg-convert', svg, '-o', ICON], check=True)
print('Icon written to', ICON, 'and', len(ALL), 'diagrams to', OUT)
