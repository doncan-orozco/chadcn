# Button (`Components::V2::Button`)

Oracle: `gems/chadcn/dev/port/oracle/src/button.tsx` (style `new-york-v4`, source_sha `79dd6f75f8136394`), manifest `gems/chadcn/dev/port/oracle/manifest/button.json`. Tier `static`: no Stimulus controller, no primitive. Exports `Button` and `buttonVariants`; one part, data-slot `button`.

## API

```ruby
Components::V2::Button.new(variant: "default", size: "default", as_child: false, class: nil, **attrs) { ... }
Components::V2::Button.variants(variant: "default", size: "default", class: nil) # => String  (React `buttonVariants`)
```

| kwarg | default (tsx) | accepted values |
|---|---|---|
| `variant:` | `"default"` (`variant = "default"`, line `function Button({ ... variant = "default"`; cva `defaultVariants.variant`) | `default`, `destructive`, `outline`, `secondary`, `ghost`, `link` |
| `size:` | `"default"` (`size = "default"`; cva `defaultVariants.size`) | `default`, `xs`, `sm`, `lg`, `icon`, `icon-xs`, `icon-sm`, `icon-lg` |
| `as_child:` | `false` (`asChild = false`) | `false` \| tag symbol (`:a`) \| a V2 component instance |
| `class:` | `nil` (`className`) | any string; merged through `cn` (tailwind_merge) after the cva output |
| `**attrs` | (`...props`, `React.ComponentProps<"button">`) | every HTML attribute: `id`, `type`, `name`, `value`, `form`, `formnovalidate`, `title`, `tabindex`, `disabled`, `style`, `data: {}`, `aria: {}` / `"aria-*":`, `role` |

- Options accept strings and symbols (shadcn-port R4): `variant: :outline` == `"outline"`; `size: :icon_sm` == `:"icon-sm"` == `"icon-sm"` (underscore normalized to the oracle's hyphen key). `nil` means the default (cva treats `undefined` as `defaultVariants`). An unknown option raises `ArgumentError` (the React TS type forbids it; cva would silently emit no classes).
- `variants(...)` is the Ruby mapping of the exported `buttonVariants` (api-mapping.md "Exceptions ... map to class methods"): returns `cn(base, variant[variant], size[size], class)` exactly like `cva(...)({ variant, size, className })`. Used by other V2 components that style non-buttons as buttons (e.g. pagination, calendar, alert-dialog actions).
- Block = `children`: text, icons (`render Components::V2::Icon.new(name: "plus")`), other components.
- `as_child:`: Radix `Slot.Root` (`const Comp = asChild ? Slot.Root : "button"`). With `as_child: :a` the part renders `<a>` with its own classes, `data-slot`, `data-variant`, `data-size` and attrs. With a component instance it calls `Components::V2::Base#render_as_child` (Radix `mergeProps`, verified in `gems/chadcn/dev/react-shadcn-catalog/node_modules/@radix-ui/react-slot/dist/index.mjs` lines 81-106): child props win (a child `data-slot` replaces `"button"`), `class` is a plain join slot-first-then-child with no tailwind_merge, `style` merged slot-then-child (child keys win), `aria-describedby` is the de-duplicated union of child ids then slot ids (`concatAriaDescribedby(childPropValue, slotPropValue)`, lines 101-102 and 135-144; note this differs from the generic "everything else child-over-slot" rule in api-mapping.md and `render_as_child` must implement it), `on*` handlers / `data-action` run child first then slot (lines 86-96). Scenarios `api__as-child-aria-describedby-merge` and `api__as-child-style-merge` pin these. The scenario harness expresses this as `"asChild": true` with one `_a` child.
- Events: none dispatched (no `on*Change` in the source). `onClick` etc. map to plain DOM events via `data: { action: "click->x#y" }`.
- `ref`: no equivalent, not part of the API.

## Structure

Single element, server-rendered in full (no Stimulus sets anything):

```html
<button data-slot="button" data-variant="{variant}" data-size="{size}" class="{cn(buttonVariants({variant,size,className}))}" ...attrs>children</button>
```

- Tag: `button` (tsx `const Comp = asChild ? Slot.Root : "button"`); with `as_child` the child's tag (`<a href>`).
- Attribute order in the source: `data-slot`, `data-variant`, `data-size`, `className`, then `{...props}` spread. Because `{...props}` comes last, a caller-supplied `data-slot`, `data-variant` or `data-size` in `**attrs` overrides the component value (React spread semantics); `class` is NOT overridable this way because `className` is destructured and fed into cva.
- `data-variant` / `data-size` carry the resolved option string with oracle spelling (`"icon-sm"`, never `"icon_sm"`), and are always present (defaults render `data-variant="default" data-size="default"`).
- No `type` attribute is added (the React source renders a bare `<button>` unless the caller passes `type`). The port must not add `type="button"`.
- `disabled: true` renders `disabled=""`; `aria-invalid: true` renders `aria-invalid="true"`; no `role`, no ids, no sr-only text, no icons owned by the component.
- Class string (cva, copied verbatim, keys identical):
  - base: `inline-flex shrink-0 items-center justify-center gap-2 rounded-md text-sm font-medium whitespace-nowrap transition-all outline-none focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50 disabled:pointer-events-none disabled:opacity-50 aria-invalid:border-destructive aria-invalid:ring-destructive/20 dark:aria-invalid:ring-destructive/40 [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4`
  - variant `default`: `bg-primary text-primary-foreground hover:bg-primary/90`
  - variant `destructive`: `bg-destructive text-white hover:bg-destructive/90 focus-visible:ring-destructive/20 dark:bg-destructive/60 dark:focus-visible:ring-destructive/40`
  - variant `outline`: `border bg-background shadow-xs hover:bg-accent hover:text-accent-foreground dark:border-input dark:bg-input/30 dark:hover:bg-input/50`
  - variant `secondary`: `bg-secondary text-secondary-foreground hover:bg-secondary/80`
  - variant `ghost`: `hover:bg-accent hover:text-accent-foreground dark:hover:bg-accent/50`
  - variant `link`: `text-primary underline-offset-4 hover:underline`
  - size `default`: `h-9 px-4 py-2 has-[>svg]:px-3`
  - size `xs`: `h-6 gap-1 rounded-md px-2 text-xs has-[>svg]:px-1.5 [&_svg:not([class*='size-'])]:size-3`
  - size `sm`: `h-8 gap-1.5 rounded-md px-3 has-[>svg]:px-2.5`
  - size `lg`: `h-10 rounded-md px-6 has-[>svg]:px-4`
  - size `icon`: `size-9`
  - size `icon-xs`: `size-6 rounded-md [&_svg:not([class*='size-'])]:size-3`
  - size `icon-sm`: `size-8`
  - size `icon-lg`: `size-10`
  - `compoundVariants`: none. `defaultVariants`: `{ variant: "default", size: "default" }`.
- Merge order: base, variant, size, caller `class`, all through `cn` (clsx + tailwind-merge), so `class: "rounded-full"` drops `rounded-md`, and duplicate `rounded-md` from base + size collapses to one token (React output identical).
- State styling is pure CSS: `hover:`, `focus-visible:`, `disabled:`, `aria-invalid:`, `dark:`, `has-[>svg]:`, `[&_svg]`. No `data-[state=*]` tokens.

## Dependencies

- None rendered by the component (`registry_dependencies: []`, no lucide import in the source).
- Needs `Components::V2::Base` for `cn`, attribute merge and `render_as_child` (Slot).
- Scenarios use lucide icons via the `<icon:...>` child convention (`Components::V2::Icon` on the Phlex side): `arrow-up`, `arrow-up-right`, `arrow-down`, `plus`, `chevron-right`, `git-branch`, `book-open`, `loader-circle`, `circle-fading-arrow-up`.
- Example substitutions (scenario-level only, identical on both harnesses, not component deviations): `button-with-icon` uses tabler `IconGitBranch` -> lucide `git-branch`; `button-loading` uses `Spinner` (not a registry dependency of button) -> lucide `loader-circle` icon; `button-as-child` uses Next `Link` -> `_a`.

## Deviations

None. No `deviations/button.json` is written.
