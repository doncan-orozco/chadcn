#!/bin/bash
# Rehearses the theme cutover (old foundation/theme.css -> shadcn-format theme/) on a SCRATCH copy of the repo and
# compares the real running app before/after. Nothing in the real repo changes. This is the executable spec of the
# `_theme` task's edits and its acceptance check.
#
#   RUNNING APP:   bin/rails server -p 3000 (any dev server whose /assets/tailwind-*.css is the app stylesheet)
#   bash .claude/scripts/shadcn/cutover_rehearsal.sh [--base http://localhost:3000] [--keep] [--samples]
#
# Needs: network (npm pack for the two vendored CSS files), a Playwright install with pngjs + pixelmatch in
# $PARITY_PLAYWRIGHT_DIR/node_modules (npm i playwright pngjs pixelmatch), optional $PARITY_CHROMIUM.
# Prints the scratch edits it applied, the CSS selector diff, and VISUAL: PASS|FAIL. Exit 1 on FAIL.
set -u
REPO="$(cd "$(dirname "$0")/../../.." && pwd)"
# Every dev-kit path comes from layout.rb (L_PORT_DIR, L_CATALOG_DIR, ...).
eval "$(ruby "$REPO/.claude/scripts/shadcn/layout.rb" --json | ruby -rjson -e 'JSON.parse($stdin.read).each { |k, v| puts "L_#{k}=#{v.inspect}" }')"
BASE="http://localhost:3000"; KEEP=0; SAMPLES=""
[ -f "$REPO/$L_SERVERS_FILE" ] && BASE="$(ruby -rjson -e 'puts JSON.parse(File.read(ARGV[0]))["rails"]["url"]' "$REPO/$L_SERVERS_FILE")" # servers.rb start
while [ $# -gt 0 ]; do case "$1" in --base) BASE="$2"; shift;; --keep) KEEP=1;; --samples) SAMPLES="--samples";; esac; shift; done
PW="${PARITY_PLAYWRIGHT_DIR:-}"
[ -n "$PW" ] && [ -d "$PW/node_modules/pixelmatch" ] || { echo "set PARITY_PLAYWRIGHT_DIR to a dir with node_modules/{playwright,pngjs,pixelmatch}"; exit 2; }
curl -s -o /dev/null "$BASE/up" || { echo "no app answering at $BASE (start bin/rails server -p 3000)"; exit 2; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/cutover.XXXXXX")"
trap '[ $KEEP -eq 1 ] || rm -rf "$WORK"' EXIT
OUT="$REPO/$L_TMP_DIR/_theme"; mkdir -p "$OUT"
rsync -a --exclude .git --exclude log --exclude tmp --exclude node_modules --exclude storage --exclude "$(basename "$L_CATALOG_DIR")" --exclude public/react-catalog "$REPO/" "$WORK/repo/"
cd "$WORK/repo" || exit 2

echo "== old-format usages that would break (must be none):"
grep -rnE 'oklch\(var\(|hsl\(var\(' app lib config --include='*.rb' --include='*.css' --include='*.js' --include='*.erb' 2>/dev/null | grep -v assets/builds | grep -v tailwind/foundation/theme.css | grep -v tailwind/theme/ || echo "none"

bin/rails tailwindcss:build > "$WORK/build-before.log" 2>&1 || { echo "BEFORE build failed"; tail -5 "$WORK/build-before.log"; exit 2; }
cp app/assets/builds/tailwind.css "$WORK/before.css"

echo "== applying the cutover (the _theme task makes these same edits in the real repo):"
mkdir -p "$WORK/pk" app/assets/tailwind/vendor
( cd "$WORK/pk" && npm pack tw-animate-css shadcn --silent >/dev/null 2>&1 && for f in *.tgz; do mkdir -p "x-${f%.tgz}" && tar -xzf "$f" -C "x-${f%.tgz}"; done )
cp "$WORK"/pk/x-tw-animate-css-*/package/dist/tw-animate.css app/assets/tailwind/vendor/tw-animate.css
cp "$WORK"/pk/x-shadcn-*/package/dist/tailwind.css app/assets/tailwind/vendor/shadcn-tailwind.css
cat > app/assets/tailwind/foundation/base.css <<'CSS'
/* Host-only global rules that are not part of a shadcn theme. */
html {
  scroll-behavior: smooth;
}

section[id] {
  scroll-margin-top: 6rem;
}
CSS
rm app/assets/tailwind/foundation/theme.css
# application.css: keep the existing imports, replace foundation/theme.css by the shadcn-format stack
ruby -e 'f="app/assets/tailwind/application.css"; s=File.read(f); stack=%(@import "./vendor/tw-animate.css";\n@import "./vendor/shadcn-tailwind.css";\n@import "./theme/theme.css";\n@import "./theme/tokens.css";\n@import "./theme/legacy-compat.css";\n@import "./foundation/base.css";); abort("no foundation/theme.css import") unless s.sub!(%r{@import "\./foundation/theme\.css";}, stack); File.write(f, s)'
echo "  application.css imports:"; grep '^@import "\./' app/assets/tailwind/application.css | sed 's/^/    /'

bin/rails tailwindcss:build > "$WORK/build-after.log" 2>&1 || { echo "AFTER build failed"; tail -8 "$WORK/build-after.log"; exit 1; }
cp app/assets/builds/tailwind.css "$WORK/after.css"
echo "== css size: before $(wc -c < "$WORK/before.css") bytes, after $(wc -c < "$WORK/after.css") bytes"
ruby -rset -e 'names=->(f){File.read(f).scan(/\.((?:\\.|[A-Za-z0-9_-])+)/).flatten.to_set}; b=names.(ARGV[0]); a=names.(ARGV[1]); gone=(b-a).to_a.grep(/\A[A-Za-z\\]/).sort; puts "== utility/class names that existed before and are gone after: #{gone.size}"; puts "   #{gone.first(30).join(" ")}" if gone.any?; puts "== new class names after (animations, data-state variants...): #{(a-b).size}"' "$WORK/before.css" "$WORK/after.css"

cd "$PW" || exit 2
node "$REPO/.claude/scripts/shadcn/visual_compare.mjs" --before "$WORK/before.css" --after "$WORK/after.css" --base "$BASE" --out "$OUT" $SAMPLES
STATUS=$?
echo "screenshots (before/after/diff) and visual-report.json: $OUT"
exit $STATUS
