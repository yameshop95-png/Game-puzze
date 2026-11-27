# strip_comments.awk — remove Dart comments while respecting string
# literals, preserving line numbers (removed text becomes spaces).
# Modes:
#   (default)            comments blanked, string contents kept.
#   -v blank_strings=1   string contents blanked (quotes kept), but
#                        ${...} interpolation is real code and is kept
#                        (and scanned) as code.
#   -v blank_triple=1    contents of triple-quoted strings blanked
#                        entirely; single-line string contents kept.
# Handles '...', "...", '''...''', """...""", raw strings (r'...',
# no escapes, no interpolation), escapes in non-raw strings, nested
# block comments (Dart nests them), and interpolation with nested
# braces and nested strings.
BEGIN {
  ctx = "code"   # code | block | str
  depth = 0      # interpolation brace depth while ctx == "code"
  bdepth = 0     # block comment nesting depth
  sp = 0         # context stack pointer
}
function push_code(d) { sp++; stk[sp] = "code:" d }
function push_str() { sp++; stk[sp] = "str:" q ":" triple ":" raw }
function pop(    s, parts) {
  if (sp == 0) { ctx = "code"; depth = 0; return }
  s = stk[sp]; delete stk[sp]; sp--
  if (substr(s, 1, 4) == "code") { ctx = "code"; depth = substr(s, 6) + 0 } else {
    ctx = "str"; split(s, parts, ":"); q = parts[2]; triple = parts[3] + 0; raw = parts[4] + 0
  }
}
function isid(ch) { return ch ~ /[A-Za-z0-9_$]/ }
{
  line = $0; out = ""; i = 1; n = length(line)
  while (i <= n) {
    c = substr(line, i, 1); c2 = substr(line, i, 2); c3 = substr(line, i, 3)
    if (ctx == "code") {
      if (c2 == "//") { out = out "  "; i = n + 1 } else if (c2 == "/*") {
        ctx = "block"; bdepth = 1; out = out "  "; i += 2
      } else if (c == "{") {
        if (depth > 0) depth++
        out = out c; i++
      } else if (c == "}") {
        if (depth > 0) {
          depth--; out = out c; i++
          if (depth == 0) pop()
        } else { out = out c; i++ }
      } else if ((c == "r" || c == "R") && (substr(line, i + 1, 1) == "'" || substr(line, i + 1, 1) == "\"") && (i == 1 || !isid(substr(line, i - 1, 1)))) {
        push_code(depth); raw = 1; q = substr(line, i + 1, 1)
        if (substr(line, i + 1, 3) == "'''" || substr(line, i + 1, 3) == "\"\"\"") {
          triple = 1; out = out c substr(line, i + 1, 3); i += 4
        } else { triple = 0; out = out c q; i += 2 }
        ctx = "str"
      } else if (c3 == "'''" || c3 == "\"\"\"") {
        push_code(depth); raw = 0; triple = 1; q = c; out = out c3; i += 3; ctx = "str"
      } else if (c == "'" || c == "\"") {
        push_code(depth); raw = 0; triple = 0; q = c; out = out c; i++; ctx = "str"
      } else { out = out c; i++ }
    } else if (ctx == "block") {
      if (c2 == "/*") { bdepth++; out = out "  "; i += 2 } else if (c2 == "*/") {
        bdepth--; out = out "  "; i += 2
        if (bdepth == 0) ctx = "code"
      } else { out = out " "; i++ }
    } else {
      # ctx == "str"
      blank = blank_strings || (blank_triple && triple)
      if (!raw && c == "\\") {
        out = out (blank ? "  " : c substr(line, i + 1, 1)); i += 2
      } else if (!raw && blank_triple && triple && c2 == "${") {
        # In blank_triple mode a triple string is blanked whole,
        # interpolation included.
        out = out "  "; i += 2
      } else if (!raw && c2 == "${") {
        # Interpolation is real code: keep it and scan it as code.
        push_str(); ctx = "code"; depth = 1; out = out c2; i += 2
      } else if (triple && c3 == q q q) {
        out = out c3; i += 3; pop()
      } else if (!triple && c == q) {
        out = out c; i++; pop()
      } else { out = out (blank ? " " : c); i++ }
    }
  }
  if (ctx == "str" && !triple) {
    # A single-line string cannot span lines; resync defensively.
    pop()
  }
  print out
}
