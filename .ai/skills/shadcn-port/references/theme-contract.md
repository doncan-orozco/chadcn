# Theme contract

shadcn theming = CSS variables in `:root` and `.dark` + Tailwind v4 `@theme inline` mapping + `--radius`. The port consumes exactly that, so any theme from ui.shadcn.com/themes pastes in unchanged. **The host owns the theme; developers edit one file.**

## Layout

```
app/assets/tailwind/theme/   (the HOST's; created by rails g chadcn:install, the dir theme:* acts on)
  theme.css          ← the ONLY file developers edit (colors between markers, optional brand extras)
  presets/           ← zinc slate stone neutral gray zinc-radius0 (copied from the gem by the install generator)
  legacy-compat.css  ← host-only shims for the frozen Ui components; delete entries as legacy disappears
app/assets/tailwind/chadcn/   (the gem's shipped default; the dummy app and the React catalog read it)
  engine.css         ← Tailwind entry of the engine: @source of the gem's Ruby + vendor + tokens, bundled as builds/tailwind/chadcn
  theme.css          ← default the generator copies into the host
  presets/           ← defaults the generator copies into the host (generated from the shadcn colors API)
  tokens.css         ← @theme inline mapping + shadcn base layer. Never edited by hand
  vendor/            ← tw-animate.css, shadcn-tailwind.css (vendored from the catalog's node_modules)
```

`application.css` imports, in order: `tailwindcss`, the engine bundle (the `chadcn` block managed by `rails g chadcn:install`: vendor CSS, tokens and the host's `theme/theme.css`), `theme/legacy-compat.css`, then the existing imports. (`tw-animate-css` and `shadcn/tailwind.css` are what the shadcn `index` registry item depends on; re-vendor with `theme_sync.rb --vendor` when the catalog's `shadcn` package changes.)

The React catalog does NOT own a copy: its `src/index.css` is `@import "tailwindcss"; @import "tw-animate-css"; @import "@host-theme/theme.css"; @import "@host-theme/tokens.css";` where Vite alias `@host-theme` -> `../../app/assets/tailwind/chadcn` (relative to the catalog). The dummy app (`dev/dummy`) points `config.chadcn.theme_dir` at the same directory, so both apps read the same files, so there is no sync step and no drift check.

## Developer workflow (this is the product)

| Goal | Command |
|---|---|
| See presets | `bin/rails theme:list` |
| Switch preset | `bin/rails theme:use[slate]` |
| Paste a theme from the shadcn site | save it to a file, `bin/rails theme:import[theme.css]` (also a URL, or `-` for stdin). Wraps old bare-HSL triplets, keeps variables the paste lacks (reports them), refuses to write an invalid theme |
| Validate | `bin/rails theme:check` (variables complete in light AND dark, no bare triplets, text contrast of every fg/bg pair; `STRICT=1` makes contrast an error) |
| Hand edit | change values inside the `theme:colors` markers, then `theme:check` |
| Live preview | design-system catalog theme panel (below) |
| Brand fonts | `theme:brand` section of `theme.css` (`@theme { --font-sans: ... }`) |

Logic lives in the gem (`lib/chadcn/theme.rb`, `Chadcn::Theme`, unit-tested in the gem's tests); the host's `theme:*` tasks are aliases of the gem's `chadcn:theme:*` tasks (`lib/tasks/`) and act on `app/assets/tailwind/theme`.

## Variable set (shadcn v4, OKLCH)

`background foreground card card-foreground popover popover-foreground primary primary-foreground secondary secondary-foreground muted muted-foreground accent accent-foreground destructive border input ring chart-1..5 sidebar sidebar-foreground sidebar-primary sidebar-primary-foreground sidebar-accent sidebar-accent-foreground sidebar-border sidebar-ring` in both `:root` and `.dark`, plus `--radius` in `:root`. The list in `Chadcn::Theme::REQUIRED` is authoritative; `theme_sync.rb --emit-presets` builds presets from `ui.shadcn.com/r/colors/<base>.json` (`cssVarsV4`), so the list matches what shadcn ships. `--check-tokens` compiles every semantic Tailwind class the oracle uses (e.g. `bg-primary/90`, `dark:ring-ring/50`, `text-sidebar-foreground`, `rounded-md`) against `tokens.css` with the real Tailwind binary and fails when one generates no CSS, or when a radius utility does not derive from `--radius` (Tailwind's own `rounded-md` would otherwise silently win).

Format rule: `--primary: oklch(0.21 0.006 285.885);` (a full color). The previous host theme stored bare channel triplets wrapped later by `oklch(var(--primary))`, which turned every pasted shadcn theme into `oklch(oklch(...))`. That format is gone. Opacity modifiers (`bg-primary/90`) work through Tailwind's `color-mix`.

## Starting point and coexistence with the live site

The first `theme.css` is **shadcn zinc** (clean baseline, same as the React catalog). The theme is global, so the `_theme` infra task does the cutover carefully:
1. Grep for direct uses of the old format (`oklch(var(--`, `hsl(var(--`, references to old variable names) and convert them to the new variables/utilities.
2. Add the `theme/*` imports, remove `foundation/theme.css` (its non-theme leftovers, smooth scroll and `section[id]` margin, move to `foundation/base.css`). Keep `legacy-compat.css` for `--destructive-foreground` and any other variable legacy components need.
3. `bin/rails tailwindcss:build`, then `bin/rails test:system`, and before/after screenshots of home, an article, studio login in light and dark under `tmp/shadcn-port/_theme/`. Report differences; the palette shift to zinc is expected, broken layout or unreadable text is not.
4. Dark mode: the legacy `ui--theme` controller toggles `html.dark` / `html.light`; shadcn needs only `.dark`. The old no-JS `prefers-color-scheme` fallback is dropped from the theme (JS mirrors the OS preference into `.dark`); if a no-JS fallback is still wanted it goes in `foundation/base.css` as a media block that sets `color-scheme` only, never re-declaring variables.

## What the cutover changes on the live site (measured by `cutover_rehearsal.sh`)

Rehearsed on the real app, 7 pages x light/dark: no element moves or resizes (0 geometry differences), 0.00-0.28% of pixels change, no new page errors. The intended differences:
- **Palette**: the old neutral becomes shadcn zinc (e.g. `oklch(0.145 0 0)` -> `oklch(0.141 0.005 285.8)`); visually close.
- **Radius**: the old theme had no `--radius`, so Tailwind's defaults applied (`rounded-md` 6px, `lg` 8px, `xl` 12px). Every `rounded-*` now derives from `--radius`; zinc ships `0.625rem`, which makes them 8, 10 and 14px. To keep the legacy radii exactly, set `--radius: 0.5rem` (sm/md/lg/xl = 4/6/8/12px). **Decided: keep the shadcn default `0.625rem`** (existing pages become 2px rounder; a later deliberate change is a one-line edit to `theme.css`).
- **`dark:` variant** is `&:is(.dark *)`: it matches descendants of `.dark`, no longer the `<html class="dark">` element itself.
- **`html.light` rule is gone**: light is the absence of `.dark`. The old no-JS `prefers-color-scheme` fallback is not reproduced.
- **Animations**: the legacy `ui-enter`/`ui-exit` rules in `utilities/motion.css` are removed; `tw-animate-css` (keyframes `enter`/`exit`, 150ms, ease, fill none) is the single source for `animate-in/out`, `fade-*`, `zoom-*` and `slide-*`, so legacy `ui/*` overlays now animate exactly like shadcn (slightly different timing/easing, no `both` fill).
- **Outline color** is set globally by the shadcn base layer (`outline-ring/50`), harmless without an outline width.
- `var(--color-primary)` etc. used directly by `reader.css` and `ui-scroll-area.css` keep resolving (`@theme inline` still emits them).

## Rules

- No component may reference a color, radius or shadow that is not a token (`design-system` R1). `text-white`, `bg-black/50` are allowed only because the oracle uses them.
- Dark mode is the `.dark` class on `<html>` (V2 controller `chadcn--theme`, toggles `.dark` only).
- `--radius` changes must change every derived `rounded-*` identically in both apps (the `zinc-radius0` preset proves it).
- Fonts load once for both apps from the same URL; `font-sans` resolves to the same family.

## Theme panel (design-system catalog)

`ShadcnParity::ThemePanel` (dev/parity, served by the dummy app at `/design-system/theme-panel`) + Stimulus `chadcn--theme-panel`: preset select (CSS embedded as JSON from the presets directory, applied by writing the variables onto `document.documentElement.style`), radius slider, light/dark toggle, per-pair contrast badges (same math as `Chadcn::Theme`, ported to JS), and a "Copy CSS" button producing a block `theme:import` accepts. Nothing is persisted; reload restores `theme.css`. Built in the `_harness` task because the parity runner reuses the same preset-injection mechanism.

## Theme gate (G4)

`parity_run.mjs --theme <preset>` injects `presets/<preset>.css` (the same `:root`/`.dark` text `theme:use` would write) into both pages after load and re-snapshots; run with `slate`, `stone`, `zinc-radius0`, and `--dark`. Any `STYLE` diff means a component hard-coded something or `tokens.css` lacks an alias.
