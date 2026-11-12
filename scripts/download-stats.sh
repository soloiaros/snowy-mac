#!/bin/bash
set -euo pipefail

if ! command -v gh >/dev/null; then
  printf '%s\n' 'Install GitHub CLI (gh) and run gh auth login first.' >&2
  exit 1
fi

use_color=0
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  use_color=1
fi
if [ "${CLICOLOR_FORCE:-0}" = "1" ]; then
  use_color=1
fi

for arg in "$@"; do
  case "$arg" in
    --no-color|--plain) use_color=0 ;;
    --color) use_color=1 ;;
  esac
done

# Fetch all pages before printing totals so an API failure cannot give partial counts.
releases="$(gh api --hostname github.com --paginate 'repos/soloiaros/snowy-mac/releases?per_page=100' --jq '
  def platform($name; $first; $second):
    .tag_name as $tag
    | [.assets[] | select(.state == "uploaded")] as $assets
    | [$assets[] | select(.name | test($first)) | .download_count] as $first_counts
    | [$assets[] | select(.name | test($second)) | .download_count] as $second_counts
    | select(($first_counts | length) + ($second_counts | length) > 0)
    | [$name, $tag, ($first_counts | add // 0), ($second_counts | add // 0)]
    | @tsv;

  .[]
  | select(.draft == false)
  | (platform("macOS";
      "^Snowy-macOS-(arm64|x86_64|universal)\\.dmg$";
      "^Snowy-macOS-(arm64|x86_64|universal)\\.zip$"),
     platform("Windows"; "^Snowy-Setup-x64\\.exe$"; "^Snowy-Setup-arm64\\.exe$"))
')"

printf '%s\n' "$releases" | awk -F '\t' \
  -v platform_specs="macOS:DMG:ZIP,Windows:x64:ARM64" \
  -v use_color="$use_color" '
function repeat(ch, n,   res, i) {
  res = ""
  for (i = 0; i < n; i++) res = res ch
  return res
}

function format_num(n,   s, r) {
  s = sprintf("%d", n)
  while (s ~ /[0-9]{4,}$/) {
    r = "," substr(s, length(s)-2) r
    s = substr(s, 1, length(s)-3)
  }
  return s r
}

BEGIN {
  if (use_color) {
    c_dim = "\033[90m"
    c_reset = "\033[0m"
    c_bold = "\033[1m"
    c_cyan = "\033[36m"
    c_blue = "\033[34m"
    c_green = "\033[1;32m"
  } else {
    c_dim = ""
    c_reset = ""
    c_bold = ""
    c_cyan = ""
    c_blue = ""
    c_green = ""
  }

  n_plats = split(platform_specs, p_list, ",")
  for (i = 1; i <= n_plats; i++) {
    split(p_list[i], parts, ":")
    p_name[i] = parts[1]
    p_col1[i] = parts[2]
    p_col2[i] = parts[3]
    p_idx[parts[1]] = i
    p_count[i] = 0
    p_tot1[i] = 0
    p_tot2[i] = 0
  }

  max_tag_w = 16
}

NF >= 4 {
  plat = $1
  tag = $2
  c1 = $3 + 0
  c2 = $4 + 0

  idx = p_idx[plat]
  if (idx > 0) {
    row = ++p_count[idx]
    p_tags[idx, row] = tag
    p_c1[idx, row] = c1
    p_c2[idx, row] = c2
    p_tot1[idx] += c1
    p_tot2[idx] += c2

    if (length(tag) > max_tag_w) {
      max_tag_w = length(tag)
    }
  }
}

END {
  tag_col_w = max_tag_w + 2
  if (tag_col_w < 18) tag_col_w = 18

  c1_w = 9
  c2_w = 9
  tot_w = 10
  gap = 2

  inner_w = tag_col_w + gap + c1_w + gap + c2_w + gap + tot_w
  W = inner_w + 4

  for (p = 1; p <= n_plats; p++) {
    plat = p_name[p]
    col1 = p_col1[p]
    col2 = p_col2[p]

    if (p > 1) print ""

    p_header_col = (plat == "macOS" ? c_cyan : (plat == "Windows" ? c_blue : c_bold))

    top_dashes = W - 2 - length(plat) - 1
    print c_dim "╭─ " c_reset p_header_col plat c_reset " " c_dim repeat("─", top_dashes) "╮" c_reset
    printf "%s│%s  %s%-*s%s  %s%*s%s  %s%*s%s  %s%*s%s  %s│%s\n", \
      c_dim, c_reset, c_bold, tag_col_w, "Release", c_reset, \
      c_bold, c1_w, col1, c_reset, \
      c_bold, c2_w, col2, c_reset, \
      c_bold, tot_w, "Total", c_reset, \
      c_dim, c_reset
    print c_dim "│  " repeat("─", inner_w) "  │" c_reset

    rows = p_count[p]
    if (rows == 0) {
      empty_msg = "No releases found"
      rem_empty = inner_w - length(empty_msg)
      if (rem_empty < 0) rem_empty = 0
      printf "%s│%s  %s%s%s%s  %s│%s\n", \
        c_dim, c_reset, c_dim, empty_msg, c_reset, repeat(" ", rem_empty), c_dim, c_reset
    } else {
      for (r = 1; r <= rows; r++) {
        t = p_tags[p, r]
        cnt1 = p_c1[p, r]
        cnt2 = p_c2[p, r]
        row_tot = cnt1 + cnt2
        printf "%s│%s  %-*s  %*s  %*s  %*s  %s│%s\n", \
          c_dim, c_reset, tag_col_w, t, \
          c1_w, format_num(cnt1), \
          c2_w, format_num(cnt2), \
          tot_w, format_num(row_tot), \
          c_dim, c_reset
      }
    }

    print c_dim "│  " repeat("─", inner_w) "  │" c_reset

    tot1 = p_tot1[p]
    tot2 = p_tot2[p]
    plat_total = tot1 + tot2
    grand_total += plat_total

    printf "%s│%s  %s%-*s%s  %s%*s%s  %s%*s%s  %s%*s%s  %s│%s\n", \
      c_dim, c_reset, c_bold, tag_col_w, "All releases", c_reset, \
      c_bold, c1_w, format_num(tot1), c_reset, \
      c_bold, c2_w, format_num(tot2), c_reset, \
      c_green, tot_w, format_num(plat_total), c_reset, \
      c_dim, c_reset
    print c_dim "╰" repeat("─", W) "╯" c_reset
  }

  # Total Installs Section
  print ""
  title = "Total Installs"
  top_dashes = W - 2 - length(title) - 1
  print c_dim "╭─ " c_reset c_bold title c_reset " " c_dim repeat("─", top_dashes) "╮" c_reset

  for (p = 1; p <= n_plats; p++) {
    plat = p_name[p]
    col1 = p_col1[p]
    col2 = p_col2[p]
    tot1 = p_tot1[p]
    tot2 = p_tot2[p]
    ptot = tot1 + tot2

    breakdown = "(" format_num(tot1) " " col1 " · " format_num(tot2) " " col2 ")"
    b_vis = 7 + length(format_num(tot1)) + length(col1) + length(format_num(tot2)) + length(col2)
    rem_spaces = inner_w - (16 + 8 + 3 + b_vis)
    if (rem_spaces < 0) rem_spaces = 0

    p_col = (plat == "macOS" ? c_cyan : (plat == "Windows" ? c_blue : c_bold))

    printf "%s│%s  %s%-16s%s%s%8s%s   %s%s%s%s  %s│%s\n", \
      c_dim, c_reset, p_col, plat, c_reset, \
      c_bold, format_num(ptot), c_reset, \
      c_dim, breakdown, c_reset, \
      repeat(" ", rem_spaces), c_dim, c_reset
  }

  print c_dim "│  " repeat("─", inner_w) "  │" c_reset

  g_label = "Grand Total"
  g_vis = 13 # "✦ " (2) + "Grand Total" (11)
  g_pad = 16 - g_vis
  g_subt = "across all platforms"
  rem_spaces = inner_w - (16 + 8 + 3 + length(g_subt))
  if (rem_spaces < 0) rem_spaces = 0

  printf "%s│%s  %s✦ %s%s%s%s%8s%s   %s%s%s%s  %s│%s\n", \
    c_dim, c_reset, c_green, g_label, c_reset, repeat(" ", g_pad), \
    c_green, format_num(grand_total), c_reset, \
    c_dim, g_subt, c_reset, \
    repeat(" ", rem_spaces), c_dim, c_reset

  print c_dim "╰" repeat("─", W) "╯" c_reset

  print ""
  print c_dim "• Counts are GitHub asset downloads. ZIPs can include in-app updates." c_reset
}
'
