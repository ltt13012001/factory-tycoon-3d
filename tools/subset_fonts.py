#!/usr/bin/env python3
"""Builds the small Noto Sans fonts the game uses for Chinese, Japanese,
Korean and Hindi, holding only the characters of data/i18n/*.json.

Fonts with every CJK character weigh 10-18 MB each; cut down to the game's
texts they are a few hundred KB, which keeps the phone and web builds small.
Run again after adding or editing translations (new characters would
otherwise fall back to the device's own fonts, or show as boxes on the web).

    pip install fonttools brotli
    # Variable fonts from https://github.com/google/fonts/tree/main/ofl
    #   notosanssc/NotoSansSC[wght].ttf, notosansjp/NotoSansJP[wght].ttf,
    #   notosanskr/NotoSansKR[wght].ttf, notosansdevanagari/NotoSansDevanagari[wdth,wght].ttf
    python3 tools/subset_fonts.py /path/to/downloaded/fonts
"""
import glob, json, pathlib, sys
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer
from fontTools import subset

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "assets/fonts"
FONTS = {  # output name -> (source file, language files whose text it covers)
    "sc": ("NotoSansSC[wght].ttf", ["zh"]),
    "jp": ("NotoSansJP[wght].ttf", ["ja"]),
    "kr": ("NotoSansKR[wght].ttf", ["ko"]),
    "devanagari": ("NotoSansDevanagari[wdth,wght].ttf", ["hi"]),
}
WEIGHTS = [400, 600]


def text_of(langs):
    chars = set()
    for lang in langs:
        data = json.load(open(ROOT / "data/i18n" / (lang + ".json"), encoding="utf-8"))
        chars.update(data["_language"]["name"])
        for v in data["strings"].values():
            chars.update(v)
    # Language names are shown in the menu whatever language is in use.
    for f in glob.glob(str(ROOT / "data/i18n/*.json")):
        chars.update(json.load(open(f, encoding="utf-8"))["_language"]["name"])
    chars.update(chr(c) for c in range(0x20, 0x7F))
    chars.update("·–—…“”‘’「」『』（）：；，。！？、＋％／")
    return "".join(sorted(c for c in chars if not c.isspace() or c == " "))


def main():
    src = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".")
    for name, (file, langs) in FONTS.items():
        text = text_of(langs)
        for w in WEIGHTS:
            font = TTFont(src / file)
            axes = {"wght": w}
            if any(a.axisTag == "wdth" for a in font["fvar"].axes):
                axes["wdth"] = 100
            font = instancer.instantiateVariableFont(font, axes)
            opts = subset.Options()
            opts.flavor = "woff2"
            opts.layout_features = ["*"]  # Devanagari needs its shaping features
            opts.name_IDs = ["*"]
            opts.notdef_outline = True
            sub = subset.Subsetter(opts)
            sub.populate(text=text)
            sub.subset(font)
            out = OUT / ("noto-sans-%s-%d.woff2" % (name, w))
            font.flavor = "woff2"
            font.save(out)
            print("%s: %d characters, %d KB" % (out.name, len(text), out.stat().st_size // 1024))


if __name__ == "__main__":
    main()
