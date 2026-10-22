# API conventions

Every component in [chadcn](../README.md) (`Chadcn`) follows the same rules, derived mechanically from the React
[shadcn/ui](https://ui.shadcn.com) source. Knowing them once is enough to read any family page.

## One class per React export

`<Root><Part>` becomes `Chadcn::<Root>::<Part>`, with the root prefix stripped once:

| React | Phlex |
|---|---|
| `Dialog` | `Chadcn::Dialog` |
| `DialogContent` | `Chadcn::Dialog::Content` |
| `DropdownMenuCheckboxItem` | `Chadcn::DropdownMenu::CheckboxItem` |
| `SelectScrollUpButton` | `Chadcn::Select::ScrollUpButton` |
| `buttonVariants(...)` | `Chadcn::Button.variants(variant:, size:, class:)` (class method, returns the class string) |

Parts live under their root and are rendered where the JSX would place them; DOM order is the order you render them. Parts that render
no element in Radix (`Root`, `Portal`, `Sub`, `Provider`, `Menubar::Menu`) exist as classes with the same API and nesting, yield their
block and emit nothing (a `display: contents` host carries the Stimulus controller where a trigger cannot).

## Two equivalent ways to compose a compound component

The nested classes are the canonical API. A compound root also yields itself, and `Chadcn::Base` generates one public helper
per nested part: the helper is the part's class name in snake_case (`Header` is `header`, `CheckboxItem` is `checkbox_item`,
`ScrollUpButton` is `scroll_up_button`), and `root.header(**attrs, &block)` is exactly `render Root::Header.new(**attrs), &block`.
Nothing else is added; the helpers are never hand-written and never carry behavior.

```ruby
# explicit
render Chadcn::Tabs.new(default_value: "account") do
  render Chadcn::Tabs::List.new do
    render Chadcn::Tabs::Trigger.new(value: "account") { "Account" }
    render Chadcn::Tabs::Trigger.new(value: "password") { "Password" }
  end
  render Chadcn::Tabs::Content.new(value: "account") { "..." }
  render Chadcn::Tabs::Content.new(value: "password") { "..." }
end

# helpers on the yielded root
render Chadcn::Tabs.new(default_value: "account") do |tabs|
  tabs.list do
    tabs.trigger(value: "account") { "Account" }
    tabs.trigger(value: "password") { "Password" }
  end
  tabs.content(value: "account") { "..." }
  tabs.content(value: "password") { "..." }
end
```

Both forms may be mixed in one view. The yielded root can be passed to another component (`render Row.new(table: table)`): the helpers
live on the instance. A few helpers share a name with an HTML element (`header`, `footer`, `title`, `label`, `link`, `input`, `menu`,
`sub`); for a caller that is harmless, since the helper renders the shadcn part.

## Props

- `className` is `class:`; camelCase props are snake_case keywords (`defaultValue` is `default_value:`, `sideOffset` is `side_offset:`);
  `children` is the block.
- Every class takes `**attrs` and passes them to its element. `class:` is merged last through tailwind-merge, so your classes win
  Tailwind conflicts; `data:` and `aria:` hashes deep-merge with the component's required attributes (flat dashed keys such as
  `"aria-label":` or `"data-state":` are folded in). React DOM prop names are mapped to the HTML attribute (`tab_index:` renders
  `tabindex`, `html_for:` renders `for`, `read_only:`, `max_length:`...). Boolean `aria`/`data` values render as `"true"`/`"false"`
  like React.
- `data-controller` and `data-action` are token lists, so they are appended instead of replaced. A `data-action` you pass follows the
  component's own (descriptors joined as given), and a `data-controller` you pass is added after the component's own controller
  names (space separated, de-duplicated). The component's own controller therefore cannot be removed from outside, not even with `controller: nil`: the
  Stimulus behavior that the markup relies on stays wired. The rule is `Base#merge_attrs` (decision record
  `dev/decisions/data-controller-merge.md`, which lives in the repository and is not packaged with the gem).

  ```ruby
  render Chadcn::Dialog.new(data: { controller: "x", action: "click->x#go" })
  # <div style="display: contents" data-controller="chadcn--dialog x" ... data-action="click->x#go"></div>
  # Dialog has no data-action of its own, so only the caller's renders.
  # data: { controller: nil } and data: { controller: "chadcn--dialog x" } render data-controller="chadcn--dialog" and
  # data-controller="chadcn--dialog x" respectively; the other data-* attributes of the host are elided above.
  ```
- Variant-like options accept strings and symbols with the React keys: `variant: "outline"` or `:outline`, `size: "icon-sm"` or
  `:icon_sm`. The defaults equal React's `defaultVariants`; an unknown value raises `ArgumentError` with the accepted values.
- `disabled: true` renders the attribute exactly as React does.

## `as_child`

`asChild` is `as_child:`. It takes `false` (the default element), a tag symbol or string (`as_child: :a` renders that tag with the
part's classes, `data-slot` and attributes) or a `Chadcn` component instance. With an instance the part's computed attributes
(`aria-*`, `data-state`, ids, `data-action`) are merged into the child with Radix Slot semantics: the child's props win, classes are
joined plainly (slot first, child second, no conflict resolution, as Radix does), `data-action` descriptors and `data-controller`
tokens are combined, `aria-describedby` ids are concatenated. `as_child: true` is not an API (there is no implicit child in Ruby).

```ruby
render Chadcn::Dialog.new do |dialog|
  dialog.trigger(as_child: Chadcn::Button.new(variant: "outline")) { "Edit profile" }
  dialog.content { dialog.title { "Edit profile" } }
end
render Chadcn::Button.new(as_child: :a, href: "/docs") { "Docs" }
```

A trigger part renders its own `<button>`; never nest a `Button` inside it as content, pass the Button to `as_child:`.

## State and events

- Uncontrolled: `default_open:`, `default_value:`, `default_checked:`, `default_pressed:` set the initial state and the controller
  keeps it in the DOM.
- Controlled: `open:`, `value:`, `checked:`, `pressed:` render that state; user actions only dispatch the change event and the server
  (or your JavaScript) renders the next state, like React's `value` + `onValueChange`.
- Callbacks are DOM events named `chadcn--<component>:<event>`, bubbling, with the payload in `event.detail`: `open-change`
  (`{ open }`), `value-change` (`{ value }`), `value-commit` (slider), `checked-change` (`{ checked }`: checkbox, switch, menu
  checkbox items), `pressed-change` (`{ pressed }`: toggle), `open-mobile-change` (sidebar), `select` (menu items), `link-select`
  (navigation menu), and the cancelable events of the overlays and menus, like Radix: `open-auto-focus` / `close-auto-focus`
  (no detail) and the dismiss events `escape-key-down` / `pointer-down-outside` / `focus-outside` / `interact-outside`
  (`{ originalEvent }`). Most are dispatched on the component's controller element. The exceptions: menu `select`,
  `checked-change` and the radio items' `value-change` fire on the item; a submenu's `open-change` fires on its `SubTrigger`;
  NavigationMenu's `link-select` fires on the link; the focus and dismiss events of DropdownMenu, ContextMenu and Menubar (and
  the dismiss events of NavigationMenu) fire on their content, except `close-auto-focus` of DropdownMenu and ContextMenu, which
  fires on their controller element (Menubar's fires on the content). Menu content is portaled to `<body>`, so listen on
  `document` for the events that fire inside it, not on the trigger. Listen with Stimulus
  (`data: { action: "chadcn--dialog:open-change->form#changed" }`) or `addEventListener`.
- Turbo: controllers that leave state in the DOM (overlays, accordion, collapsible, tabs, avatar, scroll area) listen to
  `turbo:before-cache` on `document`. The snapshot holds the closed state; a modal that was open is unmounted from it and, on a
  visit that keeps the page, re-opens afterwards (`open-auto-focus` fires again).
- Default texts: the visible and screen-reader texts of `Pagination::Previous`/`Next`/`Ellipsis`, `Sidebar::Trigger`, the mobile
  `Sidebar` sheet, the `Slider` thumbs and the `Dialog`/`Sheet` close button (`close_label:`) are keyword arguments whose defaults
  are the React strings (`label:`, `aria_label:`, `mobile_title:`, `min_label:`...). Other fixed labels (the `Pagination`,
  `Breadcrumb` and `NavigationMenu` landmarks, `Spinner`,
  `Sidebar::Rail`) are overridden through `aria: { label: ... }` (and `title:` on the rail); the caller's attributes win.
- Theme controller: `data-controller="chadcn--theme"` stores `light` or `dark` in `localStorage` under `shadcn-theme`
  (`data-chadcn--theme-storage-key-value` overrides it; `system` clears the key) and dispatches `chadcn--theme:changed`
  (`{ theme }`, one of `light`, `dark`, `system`).

## DOM contract

Every part carries `data-slot="<shadcn slot>"` (and `data-variant`, `data-size`, `data-state`, `data-side`, `data-orientation`...
where the React source emits them) on the same element as the original, with the identical Tailwind class string. Nothing in the
API changes the DOM shape; styling hooks that shadcn relies on (`has-data-[slot=...]`, `[&>svg]`, `group-data-[state=open]`) keep
working.

## Icons

`Chadcn::Icon.new(name, **attrs)` renders the Lucide icon (`"check"`, `:chevron_down`, or the lucide-react export name
`"ChevronDownIcon"`) with the lucide-react 0.577.0 markup, `aria-hidden` and no size class of its own: shadcn components size icons
through parent selectors (`[&_svg:not([class*='size-'])]:size-4`), exactly as in React.
