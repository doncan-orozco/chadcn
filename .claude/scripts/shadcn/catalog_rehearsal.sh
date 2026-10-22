#!/bin/bash
# Rehearses /shadcn-plan Phase 2 (React catalog = the oracle) on a SCRATCH copy of the repo layout.
# Nothing in the real repo changes. Needs network (npm + ui.shadcn.com) and takes a few minutes.
#
#   bash .claude/scripts/shadcn/catalog_rehearsal.sh [--keep]
#
# Prints one PASS/FAIL line per step and exits 1 if any step failed. --keep leaves the scratch dir for inspection.
set -u
REPO="$(cd "$(dirname "$0")/../../.." && pwd)"
# Every dev-kit path comes from layout.rb (L_PORT_DIR, L_CATALOG_DIR, ...).
eval "$(ruby "$REPO/.claude/scripts/shadcn/layout.rb" --json | ruby -rjson -e 'JSON.parse($stdin.read).each { |k, v| puts "L_#{k}=#{v.inspect}" }')"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/catalog-rehearsal.XXXXXX")"
KEEP=0; [ "${1:-}" = "--keep" ] && KEEP=1
FAILED=0
LOG="$WORK/rehearsal.log"
trap '[ $KEEP -eq 1 ] || rm -rf "$WORK"' EXIT

mkdir -p "$WORK/repo/$L_PORT_DIR" "$WORK/repo/$L_CATALOG_DIR" "$WORK/repo/app/assets/tailwind" "$WORK/repo/$L_TMP_DIR" "$WORK/repo/.claude"
rsync -a --exclude node_modules --exclude dist "$REPO/$L_CATALOG_DIR/" "$WORK/repo/$L_CATALOG_DIR/"
cp -r "$REPO/$L_THEME_DIR" "$WORK/repo/$L_THEME_DIR"
cp -r "$REPO/.claude/scripts" "$WORK/repo/.claude/scripts"
cp -r "$REPO/lib" "$WORK/repo/lib"
[ -f "$REPO/.ruby-version" ] && cp "$REPO/.ruby-version" "$WORK/repo/.ruby-version"
cd "$WORK/repo" || exit 2

step() { # name, command...
  local name="$1"; shift
  echo "=== $name" >> "$LOG"
  if ( "$@" ) >> "$LOG" 2>&1; then echo "PASS  $name"; else echo "FAIL  $name"; FAILED=1; fi
}

ruby .claude/scripts/shadcn/oracle_extract.rb --out "$L_ORACLE_DIR" > /dev/null 2>&1 || { echo "FAIL  oracle extraction (needs network)"; exit 1; }
ruby .claude/scripts/shadcn/oracle_audit.rb > /dev/null 2>&1 && echo "PASS  oracle audit" || { echo "FAIL  oracle audit"; FAILED=1; }
NAMES=$(ls "$L_ORACLE_DIR/manifest" | sed 's/\.json$//' | tr '\n' ' ')
mv "$L_CATALOG_DIR/src/components/ui" "$L_TMP_DIR/old-catalog-ui" 2>/dev/null

cd "$L_CATALOG_DIR" || exit 2
OLD_RADIX=$(node -e 'console.log(Object.keys(require("./package.json").dependencies).filter(d=>d.startsWith("@radix-ui/")).join(" "))')
step "2a remove old dependencies" npm rm tailwindcss-animate autoprefixer postcss $OLD_RADIX
step "2b runtime dependencies" npm i react@19 react-dom@19 tailwindcss@4 @tailwindcss/vite tw-animate-css radix-ui lucide-react class-variance-authority clsx tailwind-merge@3 --no-audit --no-fund
step "2c dev dependencies (React 19 types pinned)" npm i -D shadcn typescript vite @vitejs/plugin-react @types/node @types/react@19 @types/react-dom@19 --no-audit --no-fund
rm -f tailwind.config.js postcss.config.js
cat > components.json <<'J'
{
  "$schema": "https://ui.shadcn.com/schema.json",
  "style": "new-york",
  "rsc": false,
  "tsx": true,
  "tailwind": { "config": "", "css": "src/index.css", "baseColor": "zinc", "cssVariables": true, "prefix": "" },
  "aliases": { "components": "@/components", "utils": "@/lib/utils", "ui": "@/components/ui", "lib": "@/lib", "hooks": "@/hooks" }
}
J
# Paths from the catalog dir back to the repo root and to the theme / scenarios (the catalog may sit deeper than the root).
REL_ROOT=$(ruby -rpathname -e 'puts Pathname.new(".").relative_path_from(Pathname.new(ARGV[0]))' "$L_CATALOG_DIR")
REL_SCENARIOS=$(ruby -rpathname -e 'puts Pathname.new(ARGV[0]).relative_path_from(Pathname.new(ARGV[1]))' "$L_SCENARIOS_DIR" "$L_CATALOG_DIR")
REL_THEME=$(ruby -rpathname -e 'puts Pathname.new(ARGV[0]).relative_path_from(Pathname.new(ARGV[1]))' "$L_THEME_DIR" "$L_CATALOG_DIR")
cat > vite.config.ts <<J
/// <reference types="node" />
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'
import path from 'path'

export default defineConfig(({ command }) => ({
  plugins: [react(), tailwindcss()],
  resolve: { alias: { '@': path.resolve(__dirname, './src'), '@scenarios': path.resolve(__dirname, '$REL_SCENARIOS'), '@host-theme': path.resolve(__dirname, '$REL_THEME') } },
  server: { fs: { allow: ['..', '$REL_ROOT'] } },
  base: command === 'build' ? '/react-catalog/' : '/',
  build: { outDir: '$REL_ROOT/public/react-catalog', emptyOutDir: true },
}))
J
sed -i.bak 's/"moduleResolution": "node"/"moduleResolution": "bundler"/' tsconfig.json && rm -f tsconfig.json.bak
IMPORTS='@import "tailwindcss";\n@import "tw-animate-css";\n@import "@host-theme/theme.css";\n@import "@host-theme/tokens.css";\n'
printf "$IMPORTS" > src/index.css
step "5 shadcn add <all manifest names>" npx --yes shadcn@latest add $NAMES --overwrite --yes
printf "$IMPORTS" > src/index.css   # 5b: the CLI appends HSL sidebar variables
cd "$WORK/repo" || exit 2
step "6 verify catalog == oracle (G0)" ruby .claude/scripts/shadcn/oracle_extract.rb --out "$L_ORACLE_DIR" --verify-catalog "$L_CATALOG_DIR/src/components/ui"
step "6b vendor tw-animate + shadcn css" ruby .claude/scripts/shadcn/theme_sync.rb --vendor
step "6c tokens.css covers every semantic class" ruby .claude/scripts/shadcn/theme_sync.rb --check-tokens
step "6d cn: JS twMerge == Ruby tailwind_merge on real shadcn class strings" ruby .claude/scripts/shadcn/cn_differential.rb
step "6e playwright can launch a browser from the catalog" ruby .claude/scripts/shadcn/playwright_ensure.rb
export WORK
cd "$L_CATALOG_DIR" || exit 2
step "7 npm run build (type check + vite build)" npm run build
step "7b dev server answers GET / (base fix)" bash -c 'PORT=$((20000 + RANDOM % 20000)); (npm run dev -- --port $PORT --strictPort > $WORK/repo/dev.log 2>&1 & echo $! > $WORK/repo/dev.pid); for i in $(seq 1 40); do code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$PORT/ || true); [ "$code" = "200" ] && break; sleep 0.5; done; pkill -P $(cat $WORK/repo/dev.pid) 2>/dev/null; kill $(cat $WORK/repo/dev.pid) 2>/dev/null; [ "$code" = "200" ]'
step "7c compiled CSS has no leftover HSL variables" bash -c '! grep -q "hsl(" $WORK/repo/public/react-catalog/assets/*.css'

echo
[ $FAILED -eq 0 ] && echo "REHEARSAL: PASS" || { echo "REHEARSAL: FAIL (log: $LOG; rerun with --keep to inspect)"; [ $KEEP -eq 1 ] || cp "$LOG" "${TMPDIR:-/tmp}/catalog-rehearsal-last.log"; }
exit $FAILED
