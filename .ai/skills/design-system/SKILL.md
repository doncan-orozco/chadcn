---
name: design-system
description: "The chadcn design system, a 1:1 Phlex port of shadcn/ui: `Chadcn` in `lib/chadcn/*` with the React API (`Dialog`, `Dialog::Trigger`, `Dialog::Content`), semantic tokens, shadcn-format theme variables and the `chadcn--` Stimulus controllers. Use when creating or editing `lib/chadcn/*`, composing components in the dev kit's catalog or the docs, or touching theme tokens and presets."
---

# Design System (shadcn/ui port: `Chadcn`)

The design system is a **1:1 Phlex port of shadcn/ui (new-york-v4, Radix)**. How a component is ported, verified and kept faithful is owned by `shadcn-port` (API, classes, themes, gates) and `radix-stimulus` (behavior). This skill is the day-to-day contract for **writing and using** the components.

## Quick Rules

Cite as `design-system R<n>`.

R1. **Semantic tokens only.** `bg-primary`, `text-muted-foreground`, `border-input`...; no palette classes, hex or rgb. The only color classes allowed are the ones the shadcn source itself uses (`text-white`, `bg-black/50`). → `shadcn-port` R9
R2. **Namespace and location.** Components live in `lib/chadcn/` as `Chadcn::<Name>`, every part inherits `Chadcn::Base` (cn, attribute merging, `render_as_child`); Stimulus identifiers are `chadcn--<name>`, controllers in `app/javascript/controllers/chadcn/`. Nothing depends on a consuming application's constants. → `shadcn-port` R15
R3. **Same API as React.** One Ruby class per React export: `Dialog` -> `Chadcn::Dialog`, `DialogContent` -> `Chadcn::Dialog::Content`, `DropdownMenuCheckboxItem` -> `DropdownMenu::CheckboxItem`. Props are snake_case kwargs; `className` -> `class:`; children -> block. → `shadcn-port` references/api-mapping.md
R4. **Two equivalent ways to compose parts; the classes are canonical, the helpers are sugar.** (a) Explicit: `render Chadcn::Dialog::Content.new(...) { }`, one class per React export (used by scenarios, tests, the harness, and always valid). (b) DX helpers: the root yields itself and `Chadcn::Base` GENERATES one helper per nested part, so `render Chadcn::Table.new do |table| table.header { table.row { table.head { "Name" } } } end` reads like the JSX tree. A helper is exactly `render Root::Part.new(**attrs), &block`: never hand-written, never adds behavior. Mixing both in one view is fine. → references/compound-components.md
R5. **`**attrs` everywhere.** Every class (root and each part) takes `**attrs`, passes them through, merges `class` via `cn` (caller wins) and deep-merges `data:`/`aria:` with the component's required attributes.
R6. **Strings and symbols.** Variant-like options accept both (`variant: "outline"`, `variant: :outline`, `size: "icon-sm"`, `size: :icon_sm`); defaults equal the React `defaultVariants`.
R7. **`data-slot` on every part,** exactly the shadcn value, plus `data-variant`/`data-size` where the React source emits them.
R8. **No button inside a trigger part.** `Dialog::Trigger` renders its own `<button>`; never nest `Chadcn::Button` as its content. To render the trigger as a Button use React's own mechanism: `Dialog::Trigger.new(as_child: Chadcn::Button.new(variant: "outline"))`.
R9. **Behavior through Stimulus + shared primitives only.** No inline JS, no per-component copies of focus/dismiss/positioning logic. → `radix-stimulus`
R10. **Theme in shadcn format, one file.** The gem ships its default in `app/assets/tailwind/chadcn/theme.css` (`--primary: oklch(...)` in `:root`/`.dark`); `tokens.css` maps the variables to utilities and is never edited; `presets/*.css` are generated. A consuming application edits the copy the install generator wrote (`app/assets/tailwind/theme/theme.css`) and changes the look with `bin/rails chadcn:theme:use[preset]`, `chadcn:theme:import[...]`, `chadcn:theme:check` (`theme:*` aliases); a theme pasted from ui.shadcn.com works unchanged. Never put colors in components or other stylesheets. → `shadcn-port` references/theme-contract.md
R11. **Catalog.** Every component appears in the dev kit's catalog (`dev/dummy`, served by `bin/demo`), generated from the scenario files (no hand-written demos that can drift), and every public class and method is YARD-documented (the llms files and the agent skill are generated from it, `rake llms:check`).
R12. **Generic UI only.** The gem has no domain knowledge: no application vocabulary, no routes, no translations, no persistence. Domain composition belongs to the consuming application.
R13. **Localizable defaults.** Default strings shipped by shadcn (e.g. the sr-only "Close") are kwargs whose default equals the React string; application code passes its own text through the kwarg. Components never translate.
R14. **Verified, not eyeballed.** A component is correct only if `/shadcn-audit <name>` passes (G1-G4). Do not edit a component to "look right" without running it.

## Using the components (what a view looks like)

```ruby
render Chadcn::Dialog.new do
  render Chadcn::Dialog::Trigger.new(as_child: Chadcn::Button.new(variant: "outline")) { "Edit profile" }
  render Chadcn::Dialog::Content.new(class: "sm:max-w-[425px]") do
    render Chadcn::Dialog::Header.new do
      render Chadcn::Dialog::Title.new { "Edit profile" }
      render Chadcn::Dialog::Description.new { "Make changes to your profile here." }
    end
    render Chadcn::Dialog::Footer.new do
      render Chadcn::Button.new(type: "submit") { "Save changes" }
    end
  end
end
```
This mirrors the JSX tree one to one. The same tree with the generated helpers (the root yields itself; `Chadcn::Base` defines `trigger`, `content`, `header`, `title`, `description`, `footer`, `close`... from the nested classes):

```ruby
render Chadcn::Dialog.new do |dialog|
  dialog.trigger(as_child: Chadcn::Button.new(variant: "outline")) { "Edit profile" }
  dialog.content(class: "sm:max-w-[425px]") do
    dialog.header do
      dialog.title { "Edit profile" }
      dialog.description { "Make changes to your profile here." }
    end
    dialog.footer { render Chadcn::Button.new(type: "submit") { "Save changes" } }
  end
end
```
Components that are not compound parts (`Button`, `Input`...) are always rendered by their class. Each spec lists its helpers in the derived "DX helpers" section (`.claude/scripts/shadcn/spec_helpers.rb`). Without Rails the same code works with `.call` (README, "Without Rails").

## Where the pieces are

| Piece | Path |
|---|---|
| Components | `lib/chadcn/<name>.rb` (+ `lib/chadcn/<name>/` for large parts), all under `Chadcn::Base` |
| Base behavior (`cn`, `merge_attrs`, `render_as_child`, helper generator) | `lib/chadcn/base.rb` |
| Icons (generated lucide catalog) | `lib/chadcn/icon.rb`, `lib/chadcn/icons/` (`icons_sync.rb`) |
| Controllers and primitives | `app/javascript/controllers/chadcn/`, `app/javascript/chadcn/primitives/` |
| Theme, tokens, presets, vendored CSS | `app/assets/tailwind/chadcn/` |
| Rails integration | `lib/chadcn/engine.rb`, `lib/generators/chadcn/`, `lib/tasks/` |
| Specs, scenarios, deviations, oracle | `dev/port/` (dev kit, not packaged) |
| Docs | `README.md`, `docs/*.md` (every Ruby fence renders under `bin/smoke --docs`) |

## Companion skills

- `shadcn-port`: the port contract, gates, scenarios, theme.
- `radix-stimulus`: behavior spec and shared primitives.
- `stimulus`: controller lifecycle, targets/values, Turbo.
- `ruby-gem-conventions`: standalone code, public API, packaging.
- `accessibility`: WCAG checks beyond Radix parity.

## Quick commit check

- `/shadcn-audit changed` is green
- `bundle exec rake test` green, `rake public_api:update` + CHANGELOG entry when the public surface changed
- `rake llms:generate` run when a component's kwargs, parts or Stimulus API changed
