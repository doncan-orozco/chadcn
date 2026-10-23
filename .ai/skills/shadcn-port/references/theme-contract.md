# Theme contract

shadcn theming = CSS variables in `:root` and `.dark` + Tailwind v4 `@theme inline` mapping + `--radius`. The port consumes exactly that, so any theme from ui.shadcn.com/themes pastes in unchanged. **The gem ships the default and the tooling; the consuming application owns its copy of `theme.css` and edits that one file.**

## Layout

```
app/assets/tailwind/chadcn/   (the gem's; the dummy app and the React catalog read it directly)
  engine.css         ← Tailwind entry of the engine: its own @source for the gem's Ruby files, the vendored CSS and tokens
  theme.css          ← the default the install generator copies into an application (zinc)
  presets/           ← neutral gray zinc zinc-radius0 slate stone (generated from the shadcn colors API, copied by the generator)
  tokens.css         ← @theme inline mapping + shadcn base layer. Never edited by hand
  vendor/            ← tw-animate.css, shadcn-tailwind.css (vendored from the catalog's node_modules, theme_sync.rb --vendor)

app/assets/tailwind/theme/    (in a CONSUMING application; created by rails g chadcn:install, the directory chadcn:theme:* acts on)
  theme.css          ← the ONLY file its developers edit (colors between the theme:colors markers, optional brand extras)
  presets/           ← copies of the gem's presets (re-run the generator after a gem update; the doctor reports drift)
```

An application's Tailwind entry imports, in order: `tailwindcss`, the gem's `engine.css` (the `chadcn` block managed by `rails g chadcn:install`), then `theme/theme.css` and its own styles. Without Rails the README shows the same two imports with the gem root spelled out. `tw-animate-css` and `shadcn/tailwind.css` are what the shadcn `index` registry item depends on; re-vendor with `theme_sync.rb --vendor` when the catalog's `shadcn` package changes.

The React catalog does NOT own a copy: its `src/index.css` is `@import "tailwindcss"; @import "tw-animate-css"; @import "@host-theme/theme.css"; @import "@host-theme/tokens.css";` where the Vite alias `@host-theme` -> `../../app/assets/tailwind/chadcn` (relative to the catalog). The dummy app (`dev/dummy`) points `config.chadcn.theme_dir` at the same directory, so both apps read the same files: no sync step, no drift check.

## Developer workflow (this is the product)

In a consuming application (`bin/rails chadcn:theme:*`; `theme:*` are the short aliases unless `config.chadcn.theme_task_aliases = false`), and in the dummy app for this repository:

| Goal | Command |
|---|---|
| See presets | `bin/rails theme:list` |
| Switch preset | `bin/rails theme:use[slate]` |
| Paste a theme from the shadcn site | save it to a file, `bin/rails theme:import[theme.css]` (also an https URL, or `-` for stdin). Wraps old bare-HSL triplets, keeps variables the paste lacks (reports them), refuses to write an invalid theme |
| Validate | `bin/rails theme:check` (variables complete in light AND dark, no bare triplets, text contrast of every fg/bg pair; `STRICT=1` makes contrast an error) |
| Hand edit | change values inside the `theme:colors` markers, then `theme:check` |
| Live preview | the theme panel of the dummy app (below) |
| Brand fonts | the `theme:brand` section of `theme.css` (`@theme { --font-sans: ... }`) |

Logic lives in the gem (`lib/chadcn/theme.rb`, `Chadcn::Theme`, unit-tested in the plain suite without any network); the rake tasks (`lib/tasks/chadcn.rake`) act on `config.chadcn.theme_dir`. Run `bin/rails tailwindcss:build` after a change.

## Variable set (shadcn v4, OKLCH)

`background foreground card card-foreground popover popover-foreground primary primary-foreground secondary secondary-foreground muted muted-foreground accent accent-foreground destructive border input ring chart-1..5 sidebar sidebar-foreground sidebar-primary sidebar-primary-foreground sidebar-accent sidebar-accent-foreground sidebar-border sidebar-ring` in both `:root` and `.dark`, plus `--radius` in `:root`. The list in `Chadcn::Theme::REQUIRED` is authoritative; `theme_sync.rb --emit-presets` builds presets from `ui.shadcn.com/r/colors/<base>.json` (`cssVarsV4`), so the list matches what shadcn ships. `--check-tokens` compiles every semantic Tailwind class the oracle uses (e.g. `bg-primary/90`, `dark:ring-ring/50`, `text-sidebar-foreground`, `rounded-md`) against `tokens.css` with the real Tailwind binary and fails when one generates no CSS, or when a radius utility does not derive from `--radius` (Tailwind's own `rounded-md` would otherwise silently win).

Format rule: `--primary: oklch(0.21 0.006 285.885);` (a full color). Themes that store bare channel triplets wrapped later by `oklch(var(--primary))` turn every pasted shadcn theme into `oklch(oklch(...))`; `theme:import` wraps bare HSL triplets and `theme:check` rejects the format. Opacity modifiers (`bg-primary/90`) work through Tailwind's `color-mix`.

## Dark mode and radius

- Dark mode is the `.dark` class on `<html>`, toggled by the `chadcn--theme` controller (`.dark` only; light is the absence of `.dark`; the controller mirrors the OS preference and stores the choice under `shadcn-theme`, overridable through `storage-key`). Tailwind's `dark:` variant is `&:is(.dark *)`.
- Every `rounded-*` derives from `--radius`; the shadcn default `0.625rem` makes `rounded-md/lg/xl` 8, 10 and 14px (`--radius: 0.5rem` gives Tailwind's old 6/8/12). The `zinc-radius0` preset proves the derivation (G4).
- Animations: `tw-animate-css` (keyframes `enter`/`exit`, 150ms, ease, fill none) is the single source for `animate-in/out`, `fade-*`, `zoom-*` and `slide-*`.
- The shadcn base layer sets the outline color globally (`outline-ring/50`), harmless without an outline width.

## Rules

- No component may reference a color, radius or shadow that is not a token (`design-system` R1). `text-white`, `bg-black/50` are allowed only because the oracle uses them.
- `--radius` changes must change every derived `rounded-*` identically in the dummy app and the catalog (the `zinc-radius0` preset proves it).
- Fonts load once for both apps from the same URL; `font-sans` resolves to the same family.
- A change to `tokens.css`, `engine.css` or the vendored CSS is an infra change: `/shadcn-run` re-runs the G2 default scenarios of every `done` component (`infra-tasks.md`).

## Theme panel (dummy app)

`ShadcnParity::ThemePanel` (`dev/parity`, served by the dummy app at `/design-system/theme-panel`) + Stimulus `chadcn--theme-panel` (dev kit only, not shipped): preset select (CSS embedded as JSON from the presets directory, applied by writing the variables onto `document.documentElement.style`), radius slider, light/dark toggle, per-pair contrast badges (same math as `Chadcn::Theme`, ported to JS), and a "Copy CSS" button producing a block `theme:import` accepts. Nothing is persisted; reload restores `theme.css`.

## Theme gate (G4)

`parity_run.mjs --theme <preset>` injects `presets/<preset>.css` (the same `:root`/`.dark` text `theme:use` would write) into both pages after load and re-snapshots; run with `slate`, `stone`, `zinc-radius0`, and `--dark`. Any `STYLE` diff means a component hard-coded something or `tokens.css` lacks an alias.
