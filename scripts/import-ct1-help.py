#!/usr/bin/env python3
"""Converts CT1's German HTML-Help sources (CP1252, MS HTML Help Workshop) into a
UTF-8 help tree that WebKit can display directly.

usage: python3 -I scripts/import-ct1-help.py <cryptool1 checkout> Resources/Help/de
       python3 -I scripts/check-help.py Resources/Help/de Sources/CrypTool/Help/HelpTopics.swift
"""
import html
import os
import re
import shutil
import sys

UP = os.path.abspath(sys.argv[1])
SRC = os.path.join(UP, "CrypTool", "hlp_de")
DST = os.path.abspath(sys.argv[2])

TEXT_EXT = (".html", ".htm")

# Files referenced via the HTML-Help JScript helper parser('...'), which resolved them
# relative to the CT1 installation directory. Small ones are bundled under files/,
# the two large PDFs (≈8 MB each) are linked to their online versions.
FILE_LINKS = {
    "CT-Book-de.pdf": "https://www.cryptool.org/de/documentation/ctbook/",
    "CrypTool1-Presentation-de.pdf": "https://www.cryptool.org/de/ct1/",
    "readme-de.txt": "hid_load_readme.html",
    "DialogSchwestern.pdf": "files/DialogSchwestern.pdf",
    "ChinLab-de.pdf": "files/ChinLab-de.pdf",
    "rijndael-poster-a4.pdf": "files/rijndael-poster-a4.pdf",
    "tadicnafkeys/t-adicNAF.pdf": "files/tadicnafkeys/t-adicNAF.pdf",
}
BUNDLED = {
    "files/DialogSchwestern.pdf": "dialoguesisters/de/DialogSchwestern.pdf",
    "files/ChinLab-de.pdf": "setup/template-de/ChinLab-de.pdf",
    "files/rijndael-poster-a4.pdf": "setup/template/rijndael-poster-a4.pdf",
    "files/tadicnafkeys/t-adicNAF.pdf": "setup/template/tadicnafkeys/t-adicNAF.pdf",
}
CHALLENGES = "setup/template/cryptochallenges"


def decode(raw: bytes) -> str:
    if raw.startswith(b"\xef\xbb\xbf"):
        return raw[3:].decode("utf-8")
    try:
        return raw.decode("utf-8")
    except UnicodeDecodeError:
        pass
    out = []
    for b in raw:
        try:
            out.append(bytes([b]).decode("cp1252"))
        except UnicodeDecodeError:  # 0x81, 0x8D, 0x8F, 0x90, 0x9D are undefined in CP1252
            out.append(bytes([b]).decode("latin-1"))
    return "".join(out)


META_CHARSET = re.compile(r"<meta\b[^>]*\bcharset\s*=[^>]*>", re.I)
KEYWORD_OBJECT = re.compile(
    r"(?:<!--\s*multiple keywords for CrypTool HTML help index\s*-->\s*)?"
    r"<object\b[^>]*clsid:1e2a7bd0-dab9-11d0-b93a-00c04fc99f9e[^>]*>(.*?)</object>\s*",
    re.I | re.S)
KEYWORD_PARAM = re.compile(r"<param\b[^>]*name\s*=\s*\"keyword\"[^>]*value\s*=\s*\"([^\"]*)\"", re.I)
HELPER_SCRIPT = re.compile(r"<script\b[^>]*src\s*=\s*\"helper\.js\"[^>]*>\s*</script>\s*", re.I)
PARSER_ONCLICK = re.compile(r"onclick\s*=\s*\"parser\('([^']*)'\)\"", re.I)
ANCHOR_HASH = re.compile(r"""(<a\b[^>]*\bname\s*=\s*")#""", re.I)
LINK_ATTR = re.compile(r"""(\b(?:href|src|background)\s*=\s*)(?:"([^"]*)"|'([^']*)'|([^\s>"']+))""", re.I)
HEAD_OPEN = re.compile(r"<head\b[^>]*>", re.I)
HTML_OPEN = re.compile(r"<html\b[^>]*>", re.I)


def map_parser_target(arg: str) -> str:
    if arg.startswith(("http://", "https://")):
        return arg
    a = arg.replace("\\", "/")
    a = re.sub(r"/+", "/", a)
    if a.startswith("cryptochallenges/"):
        return "files/" + a
    if a in FILE_LINKS:
        return FILE_LINKS[a]
    raise SystemExit(f"unknown parser() target: {arg}")


def convert_html(text: str) -> str:
    keywords = []

    def drop_object(m):
        keywords.extend(html.unescape(k).strip() for k in KEYWORD_PARAM.findall(m.group(1)))
        return ""

    text = KEYWORD_OBJECT.sub(drop_object, text)
    text = HELPER_SCRIPT.sub("", text)
    # <a name="#foo"> never matched href="#foo" outside IE
    text = ANCHOR_HASH.sub(r"\1", text)
    text = PARSER_ONCLICK.sub(lambda m: 'href="%s"' % html.escape(map_parser_target(m.group(1)), quote=True), text)

    meta = '<meta charset="utf-8">'
    if keywords:
        seen = []
        for k in keywords:
            if k and k not in seen:
                seen.append(k)
        meta += '\n<meta name="keywords" content="%s">' % html.escape(", ".join(seen), quote=True)

    if META_CHARSET.search(text):
        text = META_CHARSET.sub(lambda m: meta, text, count=1)
    else:
        m = HEAD_OPEN.search(text) or HTML_OPEN.search(text)
        if m:
            text = text[:m.end()] + "\n" + meta + text[m.end():]
        else:
            text = meta + "\n" + text
    return text


def fix_link_case(root: str):
    """HTML Help resolved links case-insensitively; repair the spelling so links also work on
    case-sensitive volumes and in the help window's own lookups."""
    files = {}
    for d, _, fs in os.walk(root):
        for f in fs:
            rel = os.path.relpath(os.path.join(d, f), root).replace(os.sep, "/")
            files[rel.lower()] = rel
    count = 0
    for low, rel in list(files.items()):
        if not low.endswith(TEXT_EXT):
            continue
        path = os.path.join(root, rel)
        text = open(path, encoding="utf-8").read()
        base = os.path.dirname(rel)

        def fix(m):
            nonlocal count
            v = next(g for g in m.groups()[1:] if g is not None)
            if not v or v.startswith("#") or re.match(r"^[a-zA-Z][a-zA-Z0-9+.-]+:", v):
                return m.group(0)
            target, sep, frag = v.partition("#")
            t = target.replace("\\", "/")
            full = os.path.normpath(os.path.join(base, t)).replace(os.sep, "/")
            real = files.get(full.lower())
            if real is None or (real == full and t == target):
                return m.group(0)
            count += 1
            return m.group(1) + '"' + os.path.relpath(real, base or ".").replace(os.sep, "/") + sep + frag + '"'

        new = LINK_ATTR.sub(fix, text)
        if new != text:
            with open(path, "w", encoding="utf-8", newline="") as f:
                f.write(new)
    print(f"fixed {count} link spellings")


def write_text(path: str, text: str):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="") as f:
        f.write(text)


def build_readme(template: str, readme: str) -> str:
    """Python port of CrypTool/readme.pl."""
    s = readme.replace("\r\n", "\n")
    s = s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
    s = re.sub(r"^( *)([.A-Z0-9]+)( +\.\.\.\.? +)(.*)$", r'\1\2\3<a href="#s\2">\4</a>', s, flags=re.M)
    s = re.sub(r"^([.A-Z0-9]+\.) ([^.].*)", r'<h2><a name="s\1">\1</a> \2</h2>', s, flags=re.M)
    s = re.sub(r"----*", "", s)
    return template.replace("__BODY__", s)


def main():
    if os.path.exists(DST):
        shutil.rmtree(DST)
    os.makedirs(DST)

    for name in sorted(os.listdir(SRC)):
        p = os.path.join(SRC, name)
        if os.path.isdir(p):
            continue
        low = name.lower()
        if low.endswith(TEXT_EXT):
            text = decode(open(p, "rb").read())
            write_text(os.path.join(DST, name), convert_html(text))
        elif low.endswith(".css"):
            css = decode(open(p, "rb").read())
            css = css.replace("cursor: hand;", "cursor: pointer;")
            write_text(os.path.join(DST, name), css)
        elif low == "cryptool.hhc":
            hhc = decode(open(p, "rb").read())
            hhc = re.sub(r'<meta name="GENERATOR"[^>]*>', '<meta charset="utf-8">', hhc, count=1, flags=re.I)
            write_text(os.path.join(DST, name), hhc)

    # Readme page (CT1 generates it at build time from hid_load_readme.html.in).
    tmpl = convert_html(decode(open(os.path.join(SRC, "hid_load_readme.html.in"), "rb").read()))
    readme = decode(open(os.path.join(UP, "setup/template-de/ReadMe-de.txt"), "rb").read())
    write_text(os.path.join(DST, "hid_load_readme.html"), build_readme(tmpl, readme))

    shutil.copytree(os.path.join(SRC, "images"), os.path.join(DST, "images"))

    for dst, src in BUNDLED.items():
        os.makedirs(os.path.dirname(os.path.join(DST, dst)), exist_ok=True)
        shutil.copyfile(os.path.join(UP, src), os.path.join(DST, dst))
    cdir = os.path.join(DST, "files/cryptochallenges")
    os.makedirs(cdir, exist_ok=True)
    for name in sorted(os.listdir(os.path.join(UP, CHALLENGES))):
        if name.endswith(".txt"):
            t = decode(open(os.path.join(UP, CHALLENGES, name), "rb").read())
            write_text(os.path.join(cdir, name), t)

    fix_link_case(DST)


if __name__ == "__main__":
    main()
