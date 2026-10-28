"""Sucht Compiler-Stolpersteine (03 Code/ENTWICKLUNGSLEITFADEN.md, Abschnitt 6) in Swift-Dateien.

Aufruf im Projektordner:
    python "03 Code/tools/lint.py" --since HEAD        # geänderte + neue Dateien seit HEAD
    python "03 Code/tools/lint.py" --since 5cd0c73     # alles seit einem Commit
    python "03 Code/tools/lint.py" Pfad/zur/Datei.swift
Findet nicht alles – ersetzt keinen Build, spart aber Runden.
"""
import re
import sys
import pathlib
import subprocess

if len(sys.argv) > 1 and sys.argv[1] == "--since":
    out = subprocess.run(["git", "diff", "--name-only", sys.argv[2]], capture_output=True, text=True).stdout.split("\n")
    out += subprocess.run(["git", "ls-files", "--others", "--exclude-standard"], capture_output=True, text=True).stdout.split("\n")
    files = sorted({f.strip() for f in out if f.strip().endswith(".swift")})
else:
    files = sys.argv[1:]


def interpolations(line):
    """Inhalte aller \\( … \\)-Interpolationen einer Zeile."""
    i = 0
    result = []
    while True:
        j = line.find("\\(", i)
        if j < 0:
            break
        depth = 0
        k = j + 1
        while k < len(line):
            if line[k] == "(":
                depth += 1
            elif line[k] == ")":
                depth -= 1
                if depth == 0:
                    break
            k += 1
        result.append(line[j + 2:k])
        i = k + 1
    return result


problems = 0


def report(path, number, message, line):
    global problems
    problems += 1
    print(f"{path}:{number}: {message}: {line.strip()}")


for f in files:
    p = pathlib.Path(f)
    if not p.exists():
        continue
    lines = p.read_text(encoding="utf-8").splitlines()
    for n, line in enumerate(lines, 1):
        for expression in interpolations(line):
            if "??" in expression or re.search(r"\?\s", expression):
                report(f, n, "?? oder Ternär in Interpolation", expression)
        if re.search(r"\.map\((Format|String)\.\w+\)", line):
            report(f, n, "überladene Funktionsreferenz (Closure verwenden)", line)
        if re.search(r"\.map\(\w+\.init\)", line):
            report(f, n, "Initializer-Referenz (Closure verwenden)", line)
        if re.search(r"(foregroundStyle|fill|tint)\([^)]*\?\s*\.[a-z]\w*\s*:\s*\.[a-z]", line):
            report(f, n, "implizite Member im Ternär (Typ ausschreiben)", line)
        if re.search(r"@State[^=]*=\s*\w+\.shared\b", line):
            report(f, n, "@State mit Singleton (berechnete Eigenschaft verwenden)", line)
        if re.search(r"@ObservationIgnored\s+(private\s+)?let\b", line):
            report(f, n, "@ObservationIgnored an let", line)
        if n > 1 and re.match(r"\s*set\.", line) and re.search(r"(var \w+: [^=]+\{|get \{)\s*$", lines[n - 2]):
            report(f, n, "Getter beginnt mit 'set.' (self.set schreiben)", line)
        # `if let x = x(…)` kompiliert (Bindung gilt erst im Block), `let`/`guard let` nicht.
        m = re.match(r"\s*(?:guard )?let (\w+) = (?:try\?? |await )*(\w+)\(", line)
        if m and m.group(1) == m.group(2):
            report(f, n, "Selbstreferenz (Konstante heißt wie die Funktion)", line)

print(f"{len(files)} Dateien geprüft, {problems} Auffälligkeiten")
