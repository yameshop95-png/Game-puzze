# strip_comments.awk — remove Dart comments while respecting string
# literals, preserving line numbers (removed text becomes spaces).
# Modes:
#   (default)            comments blanked, string contents kept.
#   -v blank_strings=1   string contents are blanked too (quotes kept).
# Handles '...', "...", '''...''', """...""" and escapes inside
# non-raw strings. Raw strings (r'...') are treated as normal strings,
# which is safe here: a raw string cannot contain its own quote, so the
# end quote is still found correctly; only a backslash-quote sequence
# inside a raw string would end it early (rare; accepted limit).
BEGIN { state = "code"; q = "" }
{
  line = $0; out = ""; i = 1; n = length(line)
  while (i <= n) {
    c = substr(line, i, 1)
    c2 = substr(line, i, 2)
    c3 = substr(line, i, 3)
    if (state == "code") {
      if (c2 == "//") { out = out "  "; i = n + 1 }
      else if (c2 == "/*") { state = "block"; out = out "  "; i += 2 }
      else if (c3 == "'''" || c3 == "\"\"\"") {
        state = "str3"; q = c3; out = out c3; i += 3
      }
      else if (c == "'" || c == "\"") {
        state = "str"; q = c; out = out c; i += 1
      }
      else { out = out c; i += 1 }
    } else if (state == "block") {
      if (c2 == "*/") { state = "code"; out = out "  "; i += 2 }
      else { out = out " "; i += 1 }
    } else if (state == "str") {
      if (c == "\\") {
        if (blank_strings) { out = out "  " } else { out = out c substr(line, i + 1, 1) }
        i += 2
      } else if (c == q) { state = "code"; out = out c; i += 1 }
      else { out = out (blank_strings ? " " : c); i += 1 }
    } else if (state == "str3") {
      if (c3 == q) { state = "code"; out = out c3; i += 3 }
      else if (c == "\\") {
        if (blank_strings) { out = out "  " } else { out = out c substr(line, i + 1, 1) }
        i += 2
      }
      else { out = out (blank_strings ? " " : c); i += 1 }
    }
  }
  # A string cannot span lines unless it is triple-quoted; reset a
  # single-line string state defensively at end of line.
  if (state == "str") { state = "code" }
  print out
}
