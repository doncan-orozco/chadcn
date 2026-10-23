# Menus, select, command and combobox

[chadcn](../README.md) docs, menu family: dropdown menu, context menu, menubar and select. Their controllers
(`chadcn--dropdown-menu`, `chadcn--context-menu`, `chadcn--menubar`, `chadcn--select`) implement the Radix menu behavior: roving
focus, typeahead, submenus with the pointer grace area, checkbox and radio items, keyboard selection, and Floating UI positioning.
Conventions: [api-conventions.md](api-conventions.md).

The three menus share the same part set; the root and the trigger differ.

| Root | Root kwargs | Trigger | Events |
|---|---|---|---|
| `DropdownMenu` | `open:`, `default_open:`, `modal:` (true), `dir:`, `id:` (the content's id; the trigger is `<id>-trigger`); renders no element | `Trigger` (`as_child:`), opened by click or keyboard | `open-change`, `select`, `checked-change`, `value-change`, `open-auto-focus`, `close-auto-focus` |
| `ContextMenu` | `open:`, `dir:`, `modal:`, `id:` (the content's id); renders no element | `Trigger` (`disabled:`, `as_child:`), opened by right click or long press at the pointer | `open-change`, `select`, `checked-change`, `value-change`, `open-auto-focus`, `close-auto-focus` |
| `Menubar` | `value:`, `default_value:`, `loop:` (true), `dir:`, `as_child:`, `id:` (on the bar; its menus are `<id>-menu-N`), `**attrs` on the bar | `Menu` (`value:`) wraps one `Trigger` + `Content`; moving between triggers switches menus | `open-change`, `select`, `checked-change`, `value-change`, `open-auto-focus`, `close-auto-focus` |

Shared parts (helpers on the yielded root, `menu.<helper>`): `Portal` (`force_mount:`, `container:`) `portal`, `Content` (`side:`,
`side_offset:`, `align:`, `align_offset:`, `avoid_collisions:`, `collision_padding:`, `loop:`, `force_mount:`...) `content`, `Group`
`group`, `Label` (`inset:`) `label`, `Item` (`inset:`, `variant:` `default` / `destructive`, `disabled:`, `text_value:`, `as_child:`)
`item`, `CheckboxItem` (`checked:`, `disabled:`, `text_value:`) `checkbox_item`, `RadioGroup` (`value:`) `radio_group`, `RadioItem`
(`value:`, `disabled:`) `radio_item`, `Separator` `separator`, `Shortcut` `shortcut`, `Sub` (`open:`, `default_open:`) `sub`,
`SubTrigger` (`inset:`, `disabled:`, `text_value:`) `sub_trigger`, `SubContent` `sub_content`.

| `Select` | Root kwargs | Parts (class and generated helper) | Events |
|---|---|---|---|
| `Select` | `value:`, `default_value:`, `open:`, `default_open:`, `dir:`, `name:`, `auto_complete:`, `form:`, `disabled:`, `required:`, `id:` (the content's id; the items are `<id>-item-N`); renders no element (a hidden `<select>` is rendered for forms when `name:` is given) | `Trigger` (`size:` `default`, `sm`; `disabled:`) `select.trigger`, `Value` (`placeholder:`) `select.value`, `Content` (`position:` `item-aligned` (default) or `popper`, `side:`, `align:`, `side_offset:`...) `select.content`, `Group` `select.group`, `Label` `select.label`, `Item` (`value:`, `disabled:`, `text_value:`) `select.item`, `Separator` `select.separator`, `ScrollUpButton` `select.scroll_up_button`, `ScrollDownButton` `select.scroll_down_button` | `open-change`, `value-change`, `close-auto-focus` |

## Example: dropdown menu, both forms

```ruby
# explicit classes
render Chadcn::DropdownMenu.new do
  render Chadcn::DropdownMenu::Trigger.new(as_child: Chadcn::Button.new(variant: "outline")) { "Open" }
  render Chadcn::DropdownMenu::Content.new(class: "w-56", align: "start") do
    render Chadcn::DropdownMenu::Label.new { "My Account" }
    render Chadcn::DropdownMenu::Group.new do
      render Chadcn::DropdownMenu::Item.new do
        plain "Profile"
        render Chadcn::DropdownMenu::Shortcut.new { "⇧⌘P" }
      end
      render Chadcn::DropdownMenu::Item.new(disabled: true) { "Billing" }
    end
    render Chadcn::DropdownMenu::Separator.new
    render Chadcn::DropdownMenu::CheckboxItem.new(checked: true) { "Status Bar" }
    render Chadcn::DropdownMenu::RadioGroup.new(value: "bottom") do
      render Chadcn::DropdownMenu::RadioItem.new(value: "top") { "Top" }
      render Chadcn::DropdownMenu::RadioItem.new(value: "bottom") { "Bottom" }
    end
    render Chadcn::DropdownMenu::Sub.new do
      render Chadcn::DropdownMenu::SubTrigger.new { "Invite users" }
      render Chadcn::DropdownMenu::SubContent.new do
        render Chadcn::DropdownMenu::Item.new { "Email" }
      end
    end
    render Chadcn::DropdownMenu::Item.new(variant: "destructive") { "Log out" }
  end
end

# generated helpers
render Chadcn::DropdownMenu.new do |menu|
  menu.trigger(as_child: Chadcn::Button.new(variant: "outline")) { "Open" }
  menu.content(class: "w-56", align: "start") do
    menu.label { "My Account" }
    menu.group do
      menu.item { plain "Profile"; menu.shortcut { "⇧⌘P" } }
      menu.item(disabled: true) { "Billing" }
    end
    menu.separator
    menu.checkbox_item(checked: true) { "Status Bar" }
    menu.radio_group(value: "bottom") do
      menu.radio_item(value: "top") { "Top" }
      menu.radio_item(value: "bottom") { "Bottom" }
    end
    menu.sub do
      menu.sub_trigger { "Invite users" }
      menu.sub_content { menu.item { "Email" } }
    end
    menu.item(variant: "destructive") { "Log out" }
  end
end
```

## Example: context menu and menubar

```ruby
render Chadcn::ContextMenu.new do |menu|
  menu.trigger(class: "flex h-[150px] w-[300px] items-center justify-center rounded-md border border-dashed text-sm") { "Right click here" }
  menu.content(class: "w-52") do
    menu.item(inset: true) { plain "Back"; menu.shortcut { "⌘[" } }
    menu.item(inset: true, disabled: true) { "Forward" }
    menu.separator
    menu.checkbox_item(checked: true) { "Show Bookmarks" }
  end
end

render Chadcn::Menubar.new do |bar|
  bar.menu do
    bar.trigger { "File" }
    bar.content do
      bar.item { plain "New Tab"; bar.shortcut { "⌘T" } }
      bar.separator
      bar.sub do
        bar.sub_trigger { "Share" }
        bar.sub_content { bar.item { "Email link" } }
      end
    end
  end
  bar.menu do
    bar.trigger { "Edit" }
    bar.content { bar.item { "Undo" } }
  end
end
```

## Example: select, both forms

```ruby
# explicit classes
render Chadcn::Select.new(name: "fruit", default_value: "apple") do
  render Chadcn::Select::Trigger.new(class: "w-[180px]") { render Chadcn::Select::Value.new(placeholder: "Select a fruit") }
  render Chadcn::Select::Content.new do
    render Chadcn::Select::Group.new do
      render Chadcn::Select::Label.new { "Fruits" }
      render Chadcn::Select::Item.new(value: "apple") { "Apple" }
      render Chadcn::Select::Item.new(value: "banana") { "Banana" }
    end
  end
end

# generated helpers
render Chadcn::Select.new(name: "fruit", default_value: "apple") do |select|
  select.trigger(class: "w-[180px]") { select.value(placeholder: "Select a fruit") }
  select.content do
    select.group do
      select.label { "Fruits" }
      select.item(value: "apple") { "Apple" }
      select.item(value: "banana") { "Banana" }
    end
  end
end
```

## Notes

- Menu items dispatch `select` (cancelable: `event.preventDefault()` keeps the menu open, as Radix `onSelect`); checkbox items
  dispatch `checked-change`, radio groups `value-change`.
- `DropdownMenu`, `ContextMenu` and `Select` roots render no element; the controller lives on a `display: contents` host and the
  content is mounted into `<body>` while open (`Portal.new(container:)` to choose another container).
- `Select` keeps the chosen `value` in `Select::Value` and in the hidden native `<select>` when `name:` is given, so it submits with
  the form; `Select::Content` defaults to `position: "item-aligned"` like Radix, `position: "popper"` anchors it to the trigger.
- `Menubar.new(value:)` controls which menu is open; `loop:` wraps keyboard navigation between triggers.

## Command and combobox

Searchable lists. `Command` is shadcn's cmdk palette and `Combobox` its Base UI select-with-input; both filter with the built-in
`scorer` primitive (no fuse.js, cmdk or Base UI is loaded).

```ruby
# command palette
render Chadcn::Command.new do |command|
  command.input(placeholder: "Type a command or search...")
  command.list do
    command.empty { "No results found." }
    command.group(heading: "Suggestions") do
      command.item(value: "calendar", keywords: %w[date]) { "Calendar" }
      command.item(value: "search") { "Search emoji" }
    end
    command.separator
    command.item(disabled: true) { "Calculator" }
  end
end

# the same list in a dialog. It has no trigger slot and is controlled by open: (Cmd+K is yours to bind): re-render it with
# open: true to show it (or use default_open: true for a dialog that starts open)
render Chadcn::Command::Dialog.new(open: true) { |command| command.input(placeholder: "Search...") }

# combobox, submitted in a form as framework=next.js
render Chadcn::Combobox.new(items: %w[next.js sveltekit astro], name: "framework") do |combobox|
  combobox.input(placeholder: "Select a framework")
  combobox.content do
    combobox.empty { "No items found." }
    combobox.list { |item| combobox.item(value: item) { item } }
  end
end
```

- `Command::Item` dispatches `chadcn--command:select`; the search box dispatches `chadcn--command:search-change`. Set a custom
  matcher from JavaScript with `controller.filter = (value, search, keywords) => score`.
- `Combobox.new(multiple: true)` shows chips (`Combobox::Chips`, `Chip`, `ChipsInput`) and submits one hidden input per selection;
  `Combobox::Input.new(show_clear: true)` adds the clear button; `filter: :contains` matches like Base UI, `filter: nil` disables filtering.
- Both keep working across Turbo navigations: Command restores the server render from the page snapshot, while Combobox restores the current selection.
