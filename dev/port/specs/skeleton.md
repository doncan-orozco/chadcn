# Skeleton (`Chadcn::Skeleton`)

Oracle: `dev/port/oracle/src/skeleton.tsx` (style `new-york-v4`, source_sha `f51ce0fcd31e5c31`), manifest `dev/port/oracle/manifest/skeleton.json`. Tier `static`: no Stimulus controller, no primitive, no Radix import (`radix_primitives: []`, `use_client: false`). Single export `Skeleton`; single data-slot `skeleton`.

## API

```ruby
Chadcn::Skeleton.new(class: nil, **attrs) { ... }   # React `Skeleton`
```

| kwarg | default (tsx) | accepted values |
|---|---|---|
| `class:` | `nil` (`className`) | any string; merged through `cn` (tailwind_merge) after the base string, caller wins |
| `**attrs` | (`...props`, `React.ComponentProps<"div">`) | every HTML attribute: `id`, `role`, `style`, `title`, `data: {}`, `aria: {}` / `"aria-*":` |

- No `variant:`, `size:`, `as_child:` or any other kwarg: the source destructures only `className` and `...props` (manifest `props.destructured`). There is no `asChild`, no cva (`uses_cva: false`, `cva: {}`), so no option strings/symbols apply.
- Block = `children` (optional). The registry examples render it empty; children, when given, render inside the `div` as-is.
- Events: none dispatched. `ref`: no equivalent.

## Structure

Fully server-rendered; nothing is set by JS.

```html
<div data-slot="skeleton" class="{cn('animate-pulse rounded-md bg-accent', className)}" ...attrs>children</div>
```

- Tag: `div` (manifest `renders: "div"`).
- Attribute order in the source: `data-slot`, `className`, then `{...props}`. Because `{...props}` comes last, a caller `data-slot` in `**attrs` overrides the component value (React spread semantics; scenario `api__data-slot-override`).
- No `role`, no `aria-*` (not `aria-busy`, not `aria-hidden`), no ids, no sr-only text, no icons, no `data-state`.
- Class string, verbatim from tsx `Skeleton`: `animate-pulse rounded-md bg-accent`, then caller `class`.
- Merge via `cn`: `class: "rounded-full"` drops `rounded-md` (`skeleton-demo` avatar), `class: "rounded-xl"` drops `rounded-md` (`skeleton-card`), `class: "bg-primary"` drops `bg-accent`. Size classes (`h-4 w-[250px]`) are pure additions. Same resolved set as the React DOM.
- No state classes: no `hover:`, `focus-visible:`, `aria-invalid:`, `disabled:`, `group-*`, `peer-*`, `has-*`, `data-[state=*]`, `dark:` tokens. Dark mode only changes the resolved `--accent` value.
- `animate-pulse` is Tailwind's keyframe animation (`pulse`, opacity 1 -> .5, 2s cubic-bezier(0.4,0,0.6,1) infinite). Most scenarios run with motion disabled; `motion__pulse` runs with `animations: true` to compare the animation declaration on both sides.
- Without a height class the element has zero height (no intrinsic size); scenarios always pass `h-*`/`w-*` as the examples do, plus `empty__no-size` to compare the zero-height box.

## Dependencies

- None rendered by the component (`registry_dependencies: []`, no lucide import, `npm_dependencies: ["cn"]`).
- Needs `Chadcn::Base` for `cn` and attribute merge.
- Scenario layout wrappers use `_div` only (as in `skeleton-demo`/`skeleton-card`).

## Deviations

None. No `deviations/skeleton.json` is written.
