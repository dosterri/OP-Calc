import pathlib
"""Minimaler OpenStep-Plist-Parser zur Strukturprüfung von project.pbxproj."""
import re, sys

path = sys.argv[1] if len(sys.argv) > 1 else str(pathlib.Path(__file__).resolve().parents[2] / "OPCalc.xcodeproj" / "project.pbxproj")
s = open(path, encoding="utf-8").read()
s = re.sub(r"/\*.*?\*/", "", s, flags=re.S)
s = re.sub(r"^//.*$", "", s, flags=re.M)
pos = 0

def ws():
    global pos
    while pos < len(s) and s[pos] in " \t\r\n":
        pos += 1

def value():
    global pos
    ws()
    c = s[pos]
    if c == "{":
        pos += 1
        d = {}
        while True:
            ws()
            if s[pos] == "}":
                pos += 1
                return d
            k = scalar()
            ws()
            assert s[pos] == "=", ("expected = at", s[pos-40:pos+40])
            pos += 1
            v = value()
            ws()
            assert s[pos] == ";", ("expected ; at", s[pos-60:pos+40])
            pos += 1
            assert k not in d, ("duplicate key", k)
            d[k] = v
    if c == "(":
        pos += 1
        a = []
        while True:
            ws()
            if s[pos] == ")":
                pos += 1
                return a
            a.append(value())
            ws()
            if s[pos] == ",":
                pos += 1
            else:
                ws()
                assert s[pos] == ")", ("expected , or ) at", s[pos-40:pos+40])
    return scalar()

def scalar():
    global pos
    ws()
    if s[pos] == '"':
        pos += 1
        out = []
        while s[pos] != '"':
            if s[pos] == "\\":
                out.append(s[pos:pos+2]); pos += 2
            else:
                out.append(s[pos]); pos += 1
        pos += 1
        return "".join(out)
    m = re.compile(r"[A-Za-z0-9_$./\-+:]+").match(s, pos)
    assert m, ("bad scalar at", s[pos-40:pos+40])
    pos = m.end()
    return m.group(0)

root = value()
objs = root["objects"]
print("objects:", len(objs))
# referential integrity
def refs(v):
    if isinstance(v, dict):
        for x in v.values():
            yield from refs(x)
    elif isinstance(v, list):
        for x in v:
            yield from refs(x)
    elif isinstance(v, str) and re.fullmatch(r"[0-9A-F]{24}", v):
        yield v
missing = [r for r in refs(objs) if r not in objs and r not in (root.get("rootObject"),)]
missing += [k for o in objs.values() if isinstance(o, dict) for k in [] ]
bad = [r for r in set(refs(objs)) if r not in objs]
print("dangling refs:", bad)
for k, o in objs.items():
    if o.get("isa") == "PBXNativeTarget":
        print(o["name"], o["productType"], "phases", [objs[p]["isa"] for p in o["buildPhases"]], "groups", [objs[g]["path"] for g in o.get("fileSystemSynchronizedGroups", [])], "deps", o["dependencies"])
        for c in objs[o["buildConfigurationList"]]["buildConfigurations"]:
            bs = objs[c]["buildSettings"]
            print("  ", objs[c]["name"], bs.get("PRODUCT_BUNDLE_IDENTIFIER"), bs.get("INFOPLIST_FILE"), bs.get("SWIFT_ACTIVE_COMPILATION_CONDITIONS"))
print("OK")
