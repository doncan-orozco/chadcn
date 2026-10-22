# Input (`Components::V2::Input`)

Oracle: `gems/chadcn/dev/port/oracle/src/input.tsx` (style `new-york-v4`, source_sha `0c9457181f6ddc80`), manifest `gems/chadcn/dev/port/oracle/manifest/input.json`. Tier `static`: no Stimulus controller, no primitive, no Radix, no `"use client"`. One export `Input`, one part, data-slot `input`. No cva (`uses_cva: false`), no icons, no text literals.

## API

```ruby
Components::V2::Input.new(type: nil, class: nil, **attrs)
```

| kwarg | default (tsx) | accepted values |
|---|---|---|
| `type:` | `nil` (destructured `type` has no default; `type={undefined}` renders NO `type` attribute, so the browser default `text` applies) | any HTML input type as string or symbol (`"email"`, `:email`, `"file"`, `"password"`, `"number"`...); rendered verbatim as `type="..."`; `nil` omits the attribute |
| `class:` | `nil` (`className`) | any string, merged through `cn` (tailwind_merge) after the component classes, so the caller wins conflicts (`class: "h-12 rounded-full"` drops `h-9` and `rounded-md`) |
| `**attrs` | (`...props`, `React.ComponentProps<"input">`) | every HTML attribute of an `input`: `id`, `name`, `value`, `placeholder`, `disabled`, `readonly`, `required`, `autocomplete`, `maxlength`, `min`/`max`/`step`, `pattern`, `accept`, `multiple`, `dir`, `title`, `tabindex`, `form`, `data: {}`, `aria: {}` / `"aria-*":` (deep-merged; `aria: { invalid: true }` renders `aria-invalid="true"`) |

- React `defaultValue` maps to the plain `value:` attribute (server-rendered initial value; React's uncontrolled `defaultValue` serializes as `value="..."` in SSR and sets the same property on mount). React `value` + `onChange` (controlled) has no server equivalent: the server renders `value:`, the browser owns edits.
- `readOnly` -> `readonly: true`, `maxLength` -> `maxlength:`, `autoComplete` -> `autocomplete:`: camelCase React props map to the HTML attribute names (api-mapping.md).
- Boolean attributes render like React: `disabled: true` -> `disabled=""`, `required: true` -> `required=""`, `false`/`nil` omit them.
- The element is void: the component takes no block (a block is ignored; `children` is not valid on `<input>` in React either).
- No `as_child:` (the source never uses `Slot`), no `as:`, no events dispatched (no `on*Change` props; callers use native `input`/`change` events via `data: { action: "input->foo#bar" }`), no `ref` equivalent, no class method (nothing like `inputVariants` is exported).

## Structure

Single `input` element, fully server-rendered; nothing is set client-side. No ids generated (only a caller `id:`, typically for `<label for>`), no sr-only text, no `data-state`, no wrapper.

```html
<input type="{type}" data-slot="input" class="{cn(base, focus, invalid, className)}" ...attrs>
```

- Attribute order per tsx: `type`, `data-slot="input"`, `className`, then `{...props}`. Because the spread comes last, a caller `data-slot` in `**attrs` overrides `"input"` (React spread semantics; scenario `attrs__data-slot-override`).
- Classes, verbatim, the three `cn` arguments of tsx lines 9-13 in order:
  1. `h-9 w-full min-w-0 rounded-md border border-input bg-transparent px-3 py-1 text-base shadow-xs transition-[color,box-shadow] outline-none selection:bg-primary selection:text-primary-foreground file:inline-flex file:h-7 file:border-0 file:bg-transparent file:text-sm file:font-medium file:text-foreground placeholder:text-muted-foreground disabled:pointer-events-none disabled:cursor-not-allowed disabled:opacity-50 md:text-sm dark:bg-input/30`
  2. `focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50`
  3. `aria-invalid:border-destructive aria-invalid:ring-destructive/20 dark:aria-invalid:ring-destructive/40`
  4. caller `class:`
- States driven purely by CSS (pinned by scenarios): `focus-visible` (keyboard tab and also pointer focus, since text inputs match `:focus-visible` on click), `disabled` (dims, removes pointer events, skipped by tab), `aria-invalid="true"` (destructive border; ring colour only visible combined with focus-visible width `ring-[3px]`), `::selection` (primary background), `::placeholder` (muted foreground), `::file-selector-button` for `type="file"`, responsive `md:text-sm` (16px below 768px, 14px from 768px), dark `bg-input/30` and `dark:aria-invalid:ring-destructive/40`. No `hover:` token exists, so hover must render identically to rest.

## Dependencies

None (`registry_dependencies: []`, manifest `icons: []`). Registry examples `input-file`, `input-with-label`, `input-with-text` use `Label` and `input-with-button` uses `Button`; these are not dependencies of `input`, so their scenarios use raw `_label` (with a subset of Label's verbatim base classes, identical on both sides) and `_button` instead.

## Deviations

None.
