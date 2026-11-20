"""Supplementary source check for the named authorization modifier in this lab."""
import re
from pathlib import Path

source = Path("AuditTarget.sol").read_text(encoding="utf-8")
# Replace comments and literals before tokenizing to avoid matching documentation.
skip = r'''//[^\n]*|/\*[\s\S]*?\*/|"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*' '''
clean = re.sub(skip, lambda m: " " + "\n" * m[0].count("\n") + " ", source, flags=re.X)
definitions = list(re.finditer(r"\bmodifier\s+onlyOwner\s*\(\s*\)\s*\{", clean))
if len(definitions) != 1:
    raise SystemExit("ERROR: expected one onlyOwner() definition")
start = definitions[0].end()
depth = 1
for brace in re.finditer(r"[{}]", clean[start:]):
    depth += 1 if brace[0] == "{" else -1
    if depth == 0:
        body = clean[start:start + brace.start()]
        break
else:
    raise SystemExit("ERROR: incomplete onlyOwner body")

forbidden = re.search(r"\btx\s*\.\s*origin\b", body)
if forbidden:
    line = clean.count("\n", 0, start + forbidden.start()) + 1
    raise SystemExit(f"FAIL AuditTarget.sol:{line}: tx.origin in onlyOwner (supplementary source check)")
print("PASS: onlyOwner contains no tx.origin (supplementary source check)")
