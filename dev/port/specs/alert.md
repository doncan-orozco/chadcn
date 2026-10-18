# Alert (`Components::V2::Alert`)

Oracle: `gems/phlex-shadcn/dev/port/oracle/src/alert.tsx` (style `new-york-v4`, source_sha `d03dcae5cdb63c38`), manifest `gems/phlex-shadcn/dev/port/oracle/manifest/alert.json`. Tier `static`: no Stimulus controller, no primitive, no `"use client"`. Exports `Alert`, `AlertTitle`, `AlertDescription` (no `alertVariants` export: the cva table is module-private). Three parts, data-slots `alert`, `alert-title`, `alert-description`.

## API

```ruby
Components::V2::Alert.new(variant: "default", class: nil, **attrs) { ... }
Components::V2::Alert::Title.new(class: nil, **attrs) { ... }
Components::V2::Alert::Description.new(class: nil, **attrs) { ... }
```

| part | kwarg | default (tsx) | accepted values |
|---|---|---|---|
| `Alert` | `variant:` | `"default"` (destructured `variant` has no default in the signature; cva `defaultVariants: { variant: "default" }` applies when it is `undefined`) | `default`, `destructive` (strings or symbols, shadcn-port R4); `nil` means the default |
| all parts | `class:` | `nil` (`className`) | any string, merged through `cn` (tailwind_merge) after the component classes, so the caller wins conflicts |
| all parts | `**attrs` | (`...props`, `React.ComponentProps<"div">`) | every HTML attribute of a `div`: `id`, `title`, `tabindex`, `style`, `role`, `dir`, `hidden`, `data: {}`, `aria: {}` / `"aria-*":` (deep-merged) |

- An unknown `variant` raises `ArgumentError` (the TS type `VariantProps<typeof alertVariants>` forbids it; cva would silently emit only the base).
- Block = `children`. A lucide icon is passed by the caller as the first child (`render Components::V2::Icon.new(name: "circle-alert")`); the Alert owns no icon. The `has-[>svg]:` / `[&>svg]:` classes only react to a **direct** `svg` child.
- No `as_child:` (the source never uses `Slot`), no `as:`, no events dispatched (no `on*Change` props), no `ref` equivalent.
- No class method: React does not export `alertVariants`, so there is no `Components::V2::Alert.variants`. (A private class-level table holding the verbatim cva is an implementation detail.)

## Structure

Every part is a single `div`, server-rendered in full; nothing is set client-side. No ids, no sr-only text, no `data-state`, no `data-variant`.

```html
<div data-slot="alert" role="alert" class="{cn(alertVariants({variant}), className)}" ...attrs>
  <svg ...lucide...></svg>                                             <!-- optional, caller-provided -->
  <div data-slot="alert-title" class="{cn('col-start-2 ...', className)}" ...attrs>title</div>
  <div data-slot="alert-description" class="{cn('col-start-2 ...', className)}" ...attrs>description</div>
</div>
```

- `Alert` (tsx `function Alert`): attribute order `data-slot="alert"`, `role="alert"`, `className`, then `{...props}`. Because the spread comes last, a caller `role:` (e.g. `role: "status"`) or `data-slot` in `**attrs` overrides the component value (React spread semantics). `variant` is consumed and NOT rendered as an attribute.
- `Alert::Title` (tsx `function AlertTitle`): `data-slot="alert-title"`, `className`, `{...props}`. Tag `div` (not a heading).
- `Alert::Description` (tsx `function AlertDescription`): `data-slot="alert-description"`, `className`, `{...props}`. Tag `div`.
- DOM order is the caller's order; the parts do not reorder or wrap children.
- Classes, copied verbatim (cva `alertVariants` in tsx lines 5-20):
  - base: `relative grid w-full grid-cols-[0_1fr] items-start gap-y-0.5 rounded-lg border px-4 py-3 text-sm has-[>svg]:grid-cols-[calc(var(--spacing)*4)_1fr] has-[>svg]:gap-x-3 [&>svg]:size-4 [&>svg]:translate-y-0.5 [&>svg]:text-current`
  - `variant.default`: `bg-card text-card-foreground`
  - `variant.destructive`: `bg-card text-destructive *:data-[slot=alert-description]:text-destructive/90 [&>svg]:text-current` (the repeated `[&>svg]:text-current` is in the oracle; cva concatenates it and tailwind_merge in `cn` collapses the duplicate to one token, exactly as React's `cn` does).
  - Title: `col-start-2 line-clamp-1 min-h-4 font-medium tracking-tight`
  - Description: `col-start-2 grid justify-items-start gap-1 text-sm text-muted-foreground [&_p]:leading-relaxed`
- Composition semantics the port must not alter (pinned by scenarios): with no direct svg the grid is `0 1fr` and title/description sit in column 2; with a direct svg the first column is `--spacing*4` with `gap-x-3`; the destructive variant colors descendant descriptions through the parent's `*:data-[slot=alert-description]:` selector, so a caller `class:` on the Description competes with it via CSS specificity, not tailwind_merge.
- States: none in the source (no `hover:`, `focus-visible:`, `disabled:`, `aria-invalid:`, `data-[state]`, `dark:` tokens). Dark mode differs only through theme tokens (`--card`, `--card-foreground`, `--destructive`, `--muted-foreground`, `--border`).

<!-- spec_helpers:begin -->
## DX helpers (derived from the oracle, do not edit)

`Phlex::Shadcn::Alert` MUST `yield self` from `view_template`; `Phlex::Shadcn::Base` generates one helper per nested part (`const_added`), each exactly `render Alert::<Part>.new(**attrs), &block`. The helpers are sugar: the nested classes stay the canonical API (scenarios, tests and the parity harness use them), and fully qualified calls (`render Phlex::Shadcn::Alert::Content.new`) stay valid.

| helper | part class | React export |
|---|---|---|
| `alert.title` | `Alert::Title` | `AlertTitle` |
| `alert.description` | `Alert::Description` | `AlertDescription` |

Names that shadow a Phlex HTML element inside `Alert`'s OWN `view_template` (use `tag(:title)` there, never the bare method): `title`.

Acceptance (unit test): every row exists as a public method on the root instance and renders the same HTML as the explicit class call; no helper is defined by hand.
<!-- spec_helpers:end -->

## Dependencies

None rendered by the component itself (`registry_dependencies: []`, manifest `icons: []`). Callers and scenarios use `Components::V2::Icon` for the leading lucide icon (`circle-check`, `popcorn`, `circle-alert` in the registry `alert-demo` example: `CheckCircle2Icon`, `PopcornIcon`, `AlertCircleIcon`).

## Deviations

None.
