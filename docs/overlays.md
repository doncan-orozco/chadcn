# Overlays

Dialog, alert dialog, sheet, popover, tooltip and hover card. Each root carries a Stimulus controller (`shadcn--dialog`,
`shadcn--alert-dialog`, `shadcn--sheet`, `shadcn--popover`, `shadcn--tooltip`, `shadcn--hover-card`) that reproduces the Radix
behavior: focus trap and return, Escape and outside-pointer dismissal, scroll lock for modals, `aria-*` wiring, positioning with
Floating UI for the anchored ones. Conventions: [api-conventions.md](api-conventions.md).

| Component | Root kwargs | Parts (class and generated helper) | Events |
|---|---|---|---|
| `Dialog` | `open:`, `default_open:`, `modal:` (true), `**attrs` on the host | `Trigger` (`as_child:`) `dialog.trigger`, `Portal` (`force_mount:`, `container:`) `dialog.portal`, `Overlay` `dialog.overlay`, `Content` (`show_close_button:` true, `close_label:` "Close", `force_mount:`, `as_child:`) `dialog.content`, `Header` `dialog.header`, `Footer` `dialog.footer`, `Title` `dialog.title`, `Description` `dialog.description`, `Close` (`as_child:`) `dialog.close` | `open-change`, `open-auto-focus`, `close-auto-focus` |
| `AlertDialog` | `open:`, `default_open:`, `**attrs` | `Trigger`, `Portal`, `Overlay`, `Content` (`size:` `default`, `sm`), `Media`, `Header`, `Footer`, `Title`, `Description`, `Action` (`variant:`, `size:`, `as_child:`) `alert_dialog.action`, `Cancel` (same kwargs) `alert_dialog.cancel` | `open-change`, `open-auto-focus`, `close-auto-focus` |
| `Sheet` | `open:`, `default_open:`, `modal:`, `**attrs` | `Trigger`, `Portal`, `Overlay`, `Content` (`side:` `right`, `left`, `top`, `bottom`; `show_close_button:`, `close_label:`), `Header`, `Footer`, `Title`, `Description`, `Close` | `open-change`, `open-auto-focus`, `close-auto-focus` |
| `Popover` | `open:`, `default_open:`, `modal:` (false); renders no element | `Trigger` (`as_child:`) `popover.trigger`, `Anchor` (`as_child:`) `popover.anchor`, `Content` (`side:` bottom, `side_offset:` 4, `align:` center, `align_offset:`, `avoid_collisions:`, `collision_padding:`, `collision_boundary:`, `arrow_padding:`, `sticky:`, `hide_when_detached:`, `update_position_strategy:`, `force_mount:`) `popover.content`, `Header` `popover.header`, `Title` `popover.title`, `Description` `popover.description` | `open-change`, `open-auto-focus`, `close-auto-focus` |
| `Tooltip` | `open:`, `default_open:`, `delay_duration:`, `disable_hoverable_content:`; renders no element | `Provider` (`delay_duration:` 0, `skip_delay_duration:` 300, `disable_hoverable_content:`) `tooltip.provider`, `Trigger` (`as_child:`) `tooltip.trigger`, `Content` (`side:` top, `side_offset:` 0, `align:`... as Popover) `tooltip.content` | `open-change` |
| `HoverCard` | `open:`, `default_open:`, `open_delay:` (700), `close_delay:` (300); renders no element | `Trigger` (`as_child:`) `hover_card.trigger`, `Content` (`side:` bottom, `side_offset:` 4, ... as Popover) `hover_card.content` | `open-change` |

Closed content is shipped in an inert `<template>` at its JSX position and mounted into `<body>` (or `Portal.new(container:)`)
only while open, as Radix mounts its portal; the server-rendered `aria-labelledby` / `aria-describedby` ids resolve before any
JavaScript runs. `open:` makes the component controlled: user actions dispatch `open-change` and your code renders the next state.

## Example: dialog, both forms

```ruby
# explicit classes
render Chadcn::Dialog.new do
  render Chadcn::Dialog::Trigger.new(as_child: Chadcn::Button.new(variant: "outline")) { "Edit profile" }
  render Chadcn::Dialog::Content.new(class: "sm:max-w-[425px]") do
    render Chadcn::Dialog::Header.new do
      render Chadcn::Dialog::Title.new { "Edit profile" }
      render Chadcn::Dialog::Description.new { "Make changes to your profile here. Click save when you're done." }
    end
    render Chadcn::Dialog::Footer.new do
      render Chadcn::Dialog::Close.new(as_child: Chadcn::Button.new(variant: "outline")) { "Cancel" }
      render Chadcn::Button.new(type: "submit") { "Save changes" }
    end
  end
end

# generated helpers
render Chadcn::Dialog.new do |dialog|
  dialog.trigger(as_child: Chadcn::Button.new(variant: "outline")) { "Edit profile" }
  dialog.content(class: "sm:max-w-[425px]") do
    dialog.header do
      dialog.title { "Edit profile" }
      dialog.description { "Make changes to your profile here. Click save when you're done." }
    end
    dialog.footer do
      dialog.close(as_child: Chadcn::Button.new(variant: "outline")) { "Cancel" }
      render Chadcn::Button.new(type: "submit") { "Save changes" }
    end
  end
end
```

## Example: alert dialog and sheet

```ruby
render Chadcn::AlertDialog.new do |alert|
  alert.trigger(as_child: Chadcn::Button.new(variant: "outline")) { "Delete account" }
  alert.content do
    alert.header do
      alert.title { "Are you absolutely sure?" }
      alert.description { "This action cannot be undone." }
    end
    alert.footer do
      alert.cancel { "Cancel" }
      alert.action { "Continue" }
    end
  end
end

render Chadcn::Sheet.new do |sheet|
  sheet.trigger(as_child: Chadcn::Button.new(variant: "outline")) { "Open" }
  sheet.content(side: "left") do
    sheet.header { sheet.title { "Edit profile" } }
    sheet.footer { sheet.close(as_child: Chadcn::Button.new) { "Save changes" } }
  end
end
```

## Example: popover, tooltip and hover card

```ruby
render Chadcn::Popover.new do |popover|
  popover.trigger(as_child: Chadcn::Button.new(variant: "outline")) { "Open popover" }
  popover.content(class: "w-80", align: "start") do
    popover.header do
      popover.title { "Dimensions" }
      popover.description { "Set the dimensions for the layer." }
    end
  end
end

render Chadcn::Tooltip::Provider.new do
  render Chadcn::Tooltip.new do |tooltip|
    tooltip.trigger(as_child: Chadcn::Button.new(variant: "outline")) { "Hover" }
    tooltip.content { p { "Add to library" } }
  end
end

render Chadcn::HoverCard.new do |card|
  card.trigger(as_child: Chadcn::Button.new(variant: "link")) { "@nextjs" }
  card.content(class: "w-80") { "The React Framework" }
end
```

## Notes

- `Dialog::Close`, `Sheet::Close` and `AlertDialog::Action` / `Cancel` render a `<button>` that closes the nearest open root; pass a
  styled `Button` through `as_child:` instead of nesting one.
- `AlertDialog` is always modal and does not dismiss on outside click, like Radix; `Dialog.new(modal: false)` keeps the page
  interactive behind the content.
- `Tooltip::Provider` shares the delay and skip-delay between its tooltips; a `Tooltip` outside a provider gets its own defaults.
- `Popover::Anchor` positions the content against an element other than the trigger.
- The positioned contents take the full Radix Popper option set (`side:`, `align:`, offsets, collision handling, `sticky:`,
  `update_position_strategy:`) and expose the Radix Popper CSS variables (`--radix-popper-transform-origin`,
  `--radix-popper-available-height`, `--radix-popper-anchor-width`...) the shadcn classes use.
