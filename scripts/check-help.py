#!/usr/bin/env python3
"""Checks the converted help tree.

usage: python3 -I scripts/check-help.py Resources/Help/de [Sources/CrypTool/Help/HelpTopics.swift ...] [--fix]

  * every .html/.htm/.hhc/.css/.txt file is valid UTF-8 and declares <meta charset="utf-8">
  * every Local= target of cryptool.hhc exists (case-sensitive)
  * every relative href/src/background target exists (case-sensitive); with --fix,
    backslashes and case mismatches are repaired in place
  * #fragments of internal links point to an existing name=/id= (reported as warnings)
  * no Windows-only constructs are left (mk:@MSITStore, ms-its:, javascript:, onclick, ActiveX objects)
  * every "*.htm(l)" string literal in the given Swift files exists
"""
import os
import re
import sys
import urllib.parse

args = [a for a in sys.argv[1:] if a != "--fix"]
FIX = "--fix" in sys.argv
ROOT = os.path.abspath(args[0])
SWIFT = args[1:]

ATTR = re.compile(r"""\b(href|src|background)\s*=\s*("([^"]*)"|'([^']*)'|([^\s>"']+))""", re.I)
ANCHOR = re.compile(r"""\b(?:name|id)\s*=\s*("([^"]*)"|'([^']*)'|([^\s>"']+))""", re.I)
WINDOWS = re.compile(r"mk:@MSITStore|ms-its:|javascript:|\bonclick\s*=|clsid:|helper\.js", re.I)

all_files = {}
for d, _, fs in os.walk(ROOT):
    for f in fs:
        rel = os.path.relpath(os.path.join(d, f), ROOT).replace(os.sep, "/")
        all_files[rel] = True
lower_map = {}
for rel in all_files:
    lower_map.setdefault(rel.lower(), []).append(rel)

errors = []
warnings = []
anchors_cache = {}


def anchors_of(rel):
    if rel not in anchors_cache:
        try:
            t = open(os.path.join(ROOT, rel), encoding="utf-8").read()
        except Exception:
            t = ""
        anchors_cache[rel] = {next(g for g in m.groups()[1:] if g is not None) for m in ANCHOR.finditer(t)}
    return anchors_cache[rel]


# 1. encodings
text_files = [r for r in all_files if r.lower().endswith((".html", ".htm", ".hhc", ".css", ".txt"))]
for rel in sorted(text_files):
    raw = open(os.path.join(ROOT, rel), "rb").read()
    try:
        t = raw.decode("utf-8")
    except UnicodeDecodeError as e:
        errors.append(f"not UTF-8: {rel}: {e}")
        continue
    if rel.lower().endswith((".html", ".htm", ".hhc")):
        head = raw[:1024].decode("utf-8", "ignore").lower()
        if '<meta charset="utf-8">' not in head:
            errors.append(f"no <meta charset=utf-8> in first 1024 bytes: {rel}")
        if "windows-1252" in t.lower():
            errors.append(f"windows-1252 still declared: {rel}")
    if "�" in t:
        warnings.append(f"replacement character in {rel}")
    if rel.lower().endswith((".html", ".htm")) and WINDOWS.search(t):
        errors.append(f"Windows-only construct left in {rel}: {WINDOWS.search(t).group(0)}")
print(f"encoding: {len(text_files)} text files checked")

# 2. table of contents
hhc = open(os.path.join(ROOT, "cryptool.hhc"), encoding="utf-8").read()
locals_ = re.findall(r'<param\s+name="Local"\s+value="([^"]*)"', hhc, re.I)
missing_toc = [l for l in locals_ if l.split("#")[0] not in all_files]
for l in missing_toc:
    errors.append(f"hhc Local target missing: {l}")
print(f"toc: {len(locals_)} Local= entries, {len(missing_toc)} missing")

# 3. links
link_count = 0
fixed = 0
broken = []
frag_missing = []
for rel in sorted(r for r in all_files if r.lower().endswith((".html", ".htm"))):
    path = os.path.join(ROOT, rel)
    text = open(path, encoding="utf-8").read()
    base = os.path.dirname(rel)
    changed = False
    comments = [(c.start(), c.end()) for c in re.finditer(r"<!--.*?-->", text, re.S)]

    def check(m):
        global link_count, fixed, changed
        value = next(g for g in m.groups()[2:] if g is not None)
        pos = m.start()
        # ignore attributes inside comments or in escaped example markup (not inside a real tag)
        if any(a <= pos < b for a, b in comments) or text.rfind("<", 0, pos) < text.rfind(">", 0, pos):
            return m.group(0)
        v = value.strip()
        if not v or v.startswith("#"):
            if v.startswith("#") and len(v) > 1 and urllib.parse.unquote(v[1:]) not in anchors_of(rel):
                frag_missing.append(f"{rel} -> {v}")
            return m.group(0)
        scheme = urllib.parse.urlsplit(v).scheme.lower()
        if scheme and len(scheme) > 1:
            return m.group(0)
        link_count += 1
        target, _, frag = v.partition("#")
        target = target.split("?")[0]
        norm = urllib.parse.unquote(target).replace("\\", "/")
        full = os.path.normpath(os.path.join(base, norm)).replace(os.sep, "/")
        new_target = None
        if full not in all_files:
            cands = lower_map.get(full.lower(), [])
            if len(cands) == 1:
                new_rel = os.path.relpath(cands[0], base or ".").replace(os.sep, "/")
                new_target = new_rel
                full = cands[0]
            else:
                broken.append(f"{rel} -> {value}")
                return m.group(0)
        elif norm != target:
            new_target = norm
        if frag and full.lower().endswith((".html", ".htm")) and urllib.parse.unquote(frag) not in anchors_of(full):
            frag_missing.append(f"{rel} -> {value}")
        if new_target is not None and FIX:
            fixed += 1
            changed = True
            newval = new_target + ("#" + frag if frag else "")
            return m.group(0).replace(value, newval)
        if new_target is not None:
            broken.append(f"{rel} -> {value} (case/backslash, fixable to {new_target})")
        return m.group(0)

    new_text = ATTR.sub(check, text)
    if changed:
        with open(path, "w", encoding="utf-8", newline="") as f:
            f.write(new_text)

for b in broken:
    errors.append(f"broken link: {b}")
for f in frag_missing:
    warnings.append(f"missing anchor: {f}")
print(f"links: {link_count} relative links, {len(broken)} broken, {fixed} fixed, {len(frag_missing)} missing #anchors")

# 4. swift topics
for sw in SWIFT:
    src = open(sw, encoding="utf-8").read()
    topics = sorted(set(re.findall(r'"([A-Za-z0-9_.\-]+\.html?)"', src)))
    miss = [t for t in topics if t not in all_files]
    for t in miss:
        errors.append(f"topic in {os.path.basename(sw)} missing: {t}")
    print(f"swift: {os.path.basename(sw)}: {len(topics)} distinct topics, {len(miss)} missing")

for w in warnings:
    print("WARN ", w)
for e in errors:
    print("ERROR", e)
print(f"{len(errors)} errors, {len(warnings)} warnings")
sys.exit(1 if errors else 0)
