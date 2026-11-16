#!/usr/bin/env python3
"""Lists every Vietnamese text the game shows and updates data/i18n/*.json.

The game is written in Vietnamese: texts in the code are the originals,
wrapped in tr(). This script collects
  - every string literal with Vietnamese letters in autoload/, core/, scripts/
    (tr() texts and the tables of constants that are translated where used),
  - display_name / description / unit_name / country in data/content/*.tres,
  - a few plain-ASCII Vietnamese words listed in EXTRA below,
then, for each data/i18n/<lang>.json, adds the texts that are missing (with
an empty translation, so the game shows the Vietnamese until it is filled)
and drops texts the game no longer uses. Run from the project folder:

    python3 tools/i18n_extract.py          # update the files
    python3 tools/i18n_extract.py --check  # only report what is missing
"""
import glob, json, re, sys, pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
VN = re.compile('[àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđĐ'
                'ÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴÈÉẸẺẼÊỀẾỆỂỄÌÍỊỈĨÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠÙÚỤỦŨƯỪỨỰỬỮỲÝỴỶỸ]')
# Texts without Vietnamese letters that still need a translation.
EXTRA = ["Menu", "Kho %d/%d", "Trong kho", "Mua %d %s", "Mua %s", "Doanh thu", "Cao",
         "< Xoay", "Xoay >", "Mexico", "Indonesia", "tr", "Ngôn ngữ", "X", " (tua ×%d)", "Xem", "+ Kho"]
# Literals in these calls are for developers, not players.
SKIP = ("push_error", "push_warning", "print(", "printerr", "assert(")
# Files whose Vietnamese texts are not shown as UI text.
SKIP_FILES = {"autoload/i18n.gd"}


def unescape(lit):
    return json.loads('"' + lit.replace("\\'", "'") + '"') if "\\" in lit else lit


def literals(line):
    i, n = 0, len(line)
    while i < n:
        c = line[i]
        if c == "#":
            return
        if c in "\"'":
            q = c
            j = i + 1
            while j < n and line[j] != q:
                j += 2 if line[j] == "\\" else 1
            if q == '"' and not (i > 0 and line[i - 1] in "&^"):
                yield line[i + 1:j]
            i = j + 1
            continue
        i += 1


def collect():
    found = {}
    for path in sorted(glob.glob(str(ROOT / "autoload/*.gd")) + glob.glob(str(ROOT / "core/*.gd"))
                       + glob.glob(str(ROOT / "scripts/**/*.gd"), recursive=True) + glob.glob(str(ROOT / "data/defs/*.gd"))):
        rel = str(pathlib.Path(path).relative_to(ROOT))
        if rel in SKIP_FILES:
            continue
        for ln, line in enumerate(open(path, encoding="utf-8"), 1):
            if line.lstrip().startswith("#") or any(k in line for k in SKIP):
                continue
            for lit in literals(line):
                s = unescape(lit)
                if VN.search(s) or s in EXTRA:
                    found.setdefault(s, "%s:%d" % (rel, ln))
    for path in sorted(glob.glob(str(ROOT / "data/content/*.tres"))):
        rel = str(pathlib.Path(path).relative_to(ROOT))
        for ln, line in enumerate(open(path, encoding="utf-8"), 1):
            m = re.match(r'^(display_name|description|unit_name|country) = "(.*)"$', line.rstrip("\n"))
            if m:
                found.setdefault(unescape(m.group(2)), "%s:%d" % (rel, ln))
    for s in EXTRA:
        found.setdefault(s, "extra")
    return found


def main():
    check = "--check" in sys.argv
    found = collect()
    print("%d texts in the game" % len(found))
    bad = 0
    for path in sorted(glob.glob(str(ROOT / "data/i18n/*.json"))):
        data = json.load(open(path, encoding="utf-8"))
        old = data.get("strings", {})
        missing = [k for k in found if not old.get(k)]
        unused = [k for k in old if k not in found]
        print("%s: %d translated, %d missing, %d unused" % (pathlib.Path(path).name, len(found) - len(missing), len(missing), len(unused)))
        bad += len(missing)
        if check:
            for k in missing[:20]:
                print("   missing: %s  (%s)" % (k, found[k]))
            continue
        data["strings"] = {k: old.get(k, "") for k in found}
        with open(path, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent="\t")
            f.write("\n")
    if check and bad:
        sys.exit(1)


if __name__ == "__main__":
    main()
