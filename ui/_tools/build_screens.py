#!/usr/bin/env python3
"""Convert game UI layout XMLs (img/ui/Strings/XML) into one JSON for the screen viewer.
usage: python3 -I build_screens.py <img/ui dir> <out.json>
"""
import sys, os, re, json, glob, collections
import xml.etree.ElementTree as ET

UI, OUT = sys.argv[1], sys.argv[2]
man = json.load(open(os.path.join(UI, 'manifest.json'), encoding='utf-8'))
files = {x['path']: x for x in man['files']}
byframe = collections.defaultdict(list)
bysheet = {}
for x in man['files']:
    if 'frame' in x:
        byframe[x['frame']].append(x['path'])
        bysheet[(x['sheet'], x['frame'])] = x['path']

miss = collections.Counter()

def resolve(ref):
    """game path -> (repo-relative path, w, h) or None"""
    if not ref or ref == 'transparent':
        return None
    d = os.path.basename(os.path.dirname(ref))
    b = os.path.splitext(os.path.basename(ref))[0]
    p = bysheet.get(('Images/' + os.path.dirname(ref) + '.png', b))
    if not p and 'Images/' + ref in files:
        p = 'Images/' + ref
    if not p:
        p = '_split/%s/%s.png' % (d, b)
    if p not in files:
        c = [x for x in byframe.get(b, []) if ('/%s/' % d) in '/' + x]
        if c:
            p = c[0]
        elif 'Images/' + ref in files:
            p = 'Images/' + ref
        elif len(byframe.get(b, [])) == 1:
            p = byframe[b][0]
        elif byframe.get(b):
            p = byframe[b][0]
        else:
            miss[ref] += 1
            return {'miss': ref}
    f = files[p]
    return {'p': p, 'w': f.get('w'), 'h': f.get('h')}

def num(a, k, d=0.0):
    try:
        return float(a.get(k, d))
    except ValueError:
        return d

RGBA = re.compile(r'RGBA\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*\)')

def color(s):
    m = RGBA.search(s or '')
    if not m:
        return None
    r, g, b, a = (float(v) for v in m.groups())
    return [round(r * 255), round(g * 255), round(b * 255), round(a, 3)]

def node(el):
    a = el.attrib
    t = int(a.get('type', '1') or 1)
    n = {
        'n': a.get('name', ''), 'k': el.tag[0], 't': t,
        'x': num(a, 'x'), 'y': num(a, 'y'), 'z': num(a, 'z'),
        'w': num(a, 'width'), 'h': num(a, 'height'),
        'ax': num(a, 'anchor_x', 0.5), 'ay': num(a, 'anchor_y', 0.5),
    }
    r = num(a, 'rotation')
    if r: n['r'] = r
    if a.get('visible', '1') == '0': n['hid'] = 1
    c = color(a.get('color'))
    if c and c != [255, 255, 255, 1.0]: n['c'] = c
    if el.tag == 'Image':
        si = a.get('subinfo', '')
        m = re.match(r'^(.*?):\(\s*([-\d.]+)\s*,\s*([-\d.]+)\s*,\s*([-\d.]+)\s*,\s*([-\d.]+)\s*\)$', si)
        if m:
            si = m.group(1)
            n['s9'] = [float(v) for v in m.groups()[1:]]
        img = resolve(si)
        if img: n['img'] = img
        for key, out in (('sublanginfo', 'en'), ('selectedimginfo', 'sel'), ('disabledimginfo', 'dis')):
            if a.get(key):
                v = resolve(a[key].split(':(')[0])
                if v: n[out] = v
        if t == 13:
            n['prog'] = num(a, 'progressvalue', 0)
    elif el.tag == 'Text':
        parts = (a.get('subinfo') or '').split(':')
        tc = color(parts[0]) if parts else None
        n['txt'] = {
            'key': a.get('localizeinfo', ''),
            'c': tc or [255, 255, 255, 1],
            's': float(parts[1]) if len(parts) > 1 and parts[1] else 20,
            'f': parts[2] if len(parts) > 2 else '',
            'ha': int(a.get('HorizontalAlignment', '1') or 1),
            'va': int(a.get('VerticalAlignment', '1') or 1),
            'one': a.get('singleLine', '1') == '1',
        }
        sc = color(a.get('stroke_color'))
        if sc and num(a, 'stroke_size'):
            n['txt']['st'] = [sc, num(a, 'stroke_size')]
    kids = [node(k) for k in el]
    kids = [k for k in kids if k]
    if kids:
        kids.sort(key=lambda k: k['z'])  # stable: same z keeps document order
        n['ch'] = kids
    return n

screens = []
base = os.path.join(UI, 'Strings', 'XML')
for f in sorted(glob.glob(os.path.join(base, '**', '*.xml'), recursive=True)):
    rel = os.path.relpath(f, base).replace(os.sep, '/')
    root = ET.parse(f).getroot()
    kids = [node(k) for k in root]
    kids.sort(key=lambda k: k['z'])
    # bounding box of top-level children (for fitting cell/popup layouts)
    screens.append({'id': rel[:-4], 'root': root.tag, 'ch': kids})

json.dump({'design': man['designSize'], 'screens': screens}, open(OUT, 'w', encoding='utf-8'),
          ensure_ascii=False, separators=(',', ':'))
print(len(screens), 'screens;', sum(miss.values()), 'unresolved refs:', len(miss))
print(miss.most_common(12))
