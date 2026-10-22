# Textarea (`Components::V2::Textarea`)

Oracle: `gems/chadcn/dev/port/oracle/src/textarea.tsx` (style `new-york-v4`, source_sha `5cafcfeeee29534f`), manifest `gems/chadcn/dev/port/oracle/manifest/textarea.json`. Tier `static`: no Stimulus controller, no primitive, no Radix, no `"use client"`. One export `Textarea`, one part, data-slot `textarea`. No cva (`uses_cva: false`), no icons, no text literals. Registry examples (ui.shadcn.com `r/styles/new-york-v4`): `textarea-demo`, `textarea-disabled`, `textarea-with-label`, `textarea-with-text`, `textarea-with-button` (`textarea-form` returns 404). React DOM behaviour for `value`/`defaultValue`/children cited from `gems/chadcn/dev/react-shadcn-catalog/node_modules/react-dom/cjs/react-dom-client.development.js` (react-dom 19.3.0), cited as `rdc:<line>`.

## API

```ruby
Components::V2::Textarea.new(default_value: nil, value: nil, class: nil, **attrs) { optional initial text }
```

| kwarg | default (tsx) | accepted values |
|---|---|---|
| `default_value:` | `nil` (React `defaultValue` via `...props`, tsx line 4 `React.ComponentProps<"textarea">`) | String (or anything `to_s`-able). Rendered as the escaped text content of `<textarea>`. Mirrors React `initTextarea` (rdc:2044-2068): `element.defaultValue = value` sets the element's text content, so the DOM carries the value as its child text node, never as a `value` attribute. |
| `value:` | `nil` (React `value` via `...props`) | Same as `default_value:`. React controlled `value` also goes through `initTextarea` (rdc:2045 skips the defaulting, rdc:2061-2062 writes `element.defaultValue = value`), i.e. the same text content; so the server render is identical, no deviation. Editing afterwards is owned by the browser (no server equivalent of `onChange`). If both are given, `value:` wins (rdc:2045, React warns rdc:2017-2024). |
| block | none | Alternative to `default_value:` (React `children` on textarea is used as `defaultValue`, rdc:2046-2056). Rendered as escaped text content. If `value:` or `default_value:` is given, the block is ignored (React throws for children + defaultValue, rdc:2047-2049; with `value` children are ignored, rdc:2045). |
| `class:` | `nil` (`className`) | any string, merged through `cn` (tailwind_merge) after the component classes, so the caller wins conflicts (`class: "min-h-32 rounded-xl"` drops `min-h-16` and `rounded-md`). |
| `**attrs` | (`...props`) | every HTML attribute of a `textarea`: `id`, `name`, `placeholder`, `rows`, `cols`, `disabled`, `readonly`, `required`, `maxlength`, `minlength`, `wrap`, `autocomplete`, `dir`, `title`, `tabindex`, `form`, `data: {}`, `aria: {}` / `"aria-*":` (deep-merged; `aria: { invalid: true }` renders `aria-invalid="true"`). |

- camelCase React props map to HTML attribute names: `readOnly` -> `readonly: true`, `maxLength` -> `maxlength:`, `autoComplete` -> `autocomplete:` (api-mapping.md).
- Boolean attributes render like React: `disabled: true` -> `disabled=""`, `required: true` -> `required=""`, `readonly: true` -> `readonly=""`; `false`/`nil` omit them.
- Text content is HTML-escaped (Phlex `plain`), never raw.
- No `as_child:` (the source never uses `Slot`), no `as:`, no events dispatched (no `on*Change` props; callers use native `input`/`change` events via `data: { action: "input->foo#bar" }`), no `ref` equivalent, no class method (nothing like `textareaVariants` is exported).

## Structure

Single `textarea` element, fully server-rendered; nothing is set client-side. No ids generated (only a caller `id:`, typically for `<label for>`), no sr-only text, no `data-state`, no wrapper.

```html
<textarea data-slot="textarea" class="{cn(base, className)}" ...attrs>{value | default_value | block}</textarea>
```

- Attribute order per tsx lines 6-13: `data-slot="textarea"`, `className`, then `{...props}`. Because the spread comes last, a caller `data-slot` in `**attrs` overrides `"textarea"` (React spread semantics; scenario `attrs__data-slot-override`).
- Classes, verbatim, the first `cn` argument of tsx line 9 followed by the caller `class:`:
  `flex field-sizing-content min-h-16 w-full rounded-md border border-input bg-transparent px-3 py-2 text-base shadow-xs transition-[color,box-shadow] outline-none placeholder:text-muted-foreground focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50 disabled:cursor-not-allowed disabled:opacity-50 aria-invalid:border-destructive aria-invalid:ring-destructive/20 md:text-sm dark:bg-input/30 dark:aria-invalid:ring-destructive/40`
- States driven purely by CSS (pinned by scenarios): `field-sizing-content` (height grows with content above `min-h-16`, including typed newlines; whether `rows` still affects the height under content sizing is pinned by scenario `rows`), `focus-visible` (keyboard tab and pointer focus, since textareas match `:focus-visible` on click), `disabled` (dims, `cursor-not-allowed`, skipped by tab; note: unlike Input there is NO `disabled:pointer-events-none`), `aria-invalid="true"` (destructive border; ring colour visible combined with focus-visible `ring-[3px]`), `::placeholder` (muted foreground), responsive `md:text-sm` (16px below 768px, 14px from 768px), dark `bg-input/30` and `dark:aria-invalid:ring-destructive/40`. No `hover:` token and no `selection:` token, so hover must render identically to rest and selection uses the UA colour on both sides. No `resize-*` token: the UA resize handle stays.

## Dependencies

None (`registry_dependencies: []`, manifest `icons: []`). Registry examples `textarea-with-label` and `textarea-with-text` use `Label`, and `textarea-with-button` uses `Button`; these are not dependencies of `textarea`, so their scenarios use raw `_label` (with the subset of Label's base classes used by the input scenarios, identical on both sides) and `_button` instead.

## Deviations

None.
