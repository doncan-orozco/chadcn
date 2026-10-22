# Display components

[chadcn](../README.md) docs, display family. Static building blocks: no Stimulus controller is needed except for `Avatar` (image
loading state) and `Toaster` (toasts). Conventions shared by every component: [api-conventions.md](api-conventions.md).

| Component | Root kwargs (besides `**attrs`) | Parts (class and generated helper) |
|---|---|---|
| `Alert` | `variant:` (`default`, `destructive`) | `Title` `alert.title`, `Description` `alert.description` |
| `AspectRatio` | `ratio:` (default 1), `as_child:`, `style:` | none |
| `Avatar` | `size:` (`default`, `sm`, `lg`), `as_child:` | `Image` (`src:`, `as_child:`) `avatar.image`, `Fallback` (`delay_ms:`, `as_child:`) `avatar.fallback`, `Badge` `avatar.badge`, `Group` `avatar.group`, `GroupCount` `avatar.group_count` |
| `Badge` | `variant:` (`default`, `secondary`, `destructive`, `outline`, `ghost`, `link`), `as_child:`; `Badge.variants(variant:, class:)` | none |
| `Bubble` | `variant:` (`default`, `secondary`, `muted`, `tinted`, `outline`, `ghost`, `destructive`), `align:` (`start`, `end`) | `Group` `bubble.group`, `Content` (`as_child:`) `bubble.content`, `Reactions` (`side:`, `align:`) `bubble.reactions` |
| `Card` | none | `Header` `card.header`, `Title` `card.title`, `Description` `card.description`, `Action` `card.action`, `Content` `card.content`, `Footer` `card.footer` |
| `Empty` | none | `Header` `empty.header`, `Media` (`variant:` `default`, `icon`) `empty.media`, `Title` `empty.title`, `Description` `empty.description`, `Content` `empty.content` |
| `Kbd` | none | `Group` `kbd.group` |
| `Marker` | `variant:`, `as_child:`; `Marker.variants` | `Icon` `marker.icon`, `Content` `marker.content` |
| `Message` | `align:` (`start`, `end`) | `Group` `message.group`, `Avatar` `message.avatar`, `Content` `message.content`, `Header` `message.header`, `Footer` `message.footer` |
| `Progress` | `value:`, `max:` | none |
| `Separator` | `orientation:` (`horizontal`, `vertical`), `decorative:` (true), `as_child:` | none |
| `Skeleton` | none | none |
| `Spinner` | none | none |
| `Toaster` (`Sonner::Toaster`; `Sonner` is the root that renders it and offers `sonner.toast`) | `position:`, `theme:`, `rich_colors:`, `expand:`, `close_button:`, `invert:`, `duration:`, `visible_toasts:`, `gap:`, `offset:`, `mobile_offset:`, `dir:`, `hotkey:`, `container_aria_label:`, `swipe_directions:`, `toast_options:`, `icons:`, `style:`, `toaster_id:`, `flash:`, `toasts:` | `Sonner::Toast` (`title:`, `description:`, `type:`, `id:`, `duration:`, `position:`, `dismissible:`, `close_button:`, `rich_colors:`, `invert:`, `icon:`, `action:`, `cancel:`, `toaster_id:`, `test_id:`), rendered inside the Toaster or appended to it |
| `Table` | none (attributes go to the inner `<table>`; the scroll container is fixed) | `Header` `table.header`, `Body` `table.body`, `Footer` `table.footer`, `Row` `table.row`, `Head` `table.head`, `Cell` `table.cell`, `Caption` `table.caption` |
| `Item` | `variant:` (`default`, `outline`, `muted`), `size:` (`default`, `sm`), `as_child:`; `Item.variants` | `Media` (`variant:`) `item.media`, `Content` `item.content`, `Actions` `item.actions`, `Group` `item.group`, `Title` `item.title`, `Description` `item.description`, `Header` `item.header`, `Footer` `item.footer`, `Separator` `item.separator` |
| `Attachment` | `state:` (`idle`, `uploading`, `processing`, `error`, `done`), `size:` (`default`, `sm`, `xs`), `orientation:` (`horizontal`, `vertical`) | `Group` `attachment.group`, `Media` (`variant:`) `attachment.media`, `Content` `attachment.content`, `Title` `attachment.title`, `Description` `attachment.description`, `Actions` `attachment.actions`, `Action` (`variant:`, `size:`) `attachment.action`, `Trigger` (`as_child:`, `type:`) `attachment.trigger` |

The exact accepted values of every option are the keys of the component's `VARIANTS` / `SIZES` tables in the YARD documentation;
passing a symbol (`variant: :destructive`) is the same as the string.

## Example: a card, both forms

```ruby
# explicit classes
render Chadcn::Card.new(class: "w-full max-w-sm") do
  render Chadcn::Card::Header.new do
    render Chadcn::Card::Title.new { "Login to your account" }
    render Chadcn::Card::Description.new { "Enter your email below to login to your account" }
    render Chadcn::Card::Action.new { render Chadcn::Button.new(variant: "link") { "Sign Up" } }
  end
  render Chadcn::Card::Content.new { render Chadcn::Input.new(type: "email", placeholder: "m@example.com") }
  render Chadcn::Card::Footer.new(class: "flex-col gap-2") do
    render Chadcn::Button.new(type: "submit", class: "w-full") { "Login" }
  end
end

# generated helpers
render Chadcn::Card.new(class: "w-full max-w-sm") do |card|
  card.header do
    card.title { "Login to your account" }
    card.description { "Enter your email below to login to your account" }
    card.action { render Chadcn::Button.new(variant: "link") { "Sign Up" } }
  end
  card.content { render Chadcn::Input.new(type: "email", placeholder: "m@example.com") }
  card.footer(class: "flex-col gap-2") { render Chadcn::Button.new(type: "submit", class: "w-full") { "Login" } }
end
```

## Example: a table

```ruby
render Chadcn::Table.new do |table|
  table.caption { "A list of your recent invoices." }
  table.header do
    table.row do
      table.head(class: "w-[100px]") { "Invoice" }
      table.head(class: "text-right") { "Amount" }
    end
  end
  table.body do
    invoices.each do |invoice|
      table.row do
        table.cell(class: "font-medium") { invoice.number }
        table.cell(class: "text-right") { invoice.amount }
      end
    end
  end
end
```

`table.row`, `table.cell`... are available on the yielded instance wherever you pass it, so a row can be its own component that
receives `table:`.

## Toasts: the Toaster

`Toaster` is the shadcn export of sonner. Render it once, in the layout; toasts reach it three ways, with no JavaScript dependency (the
`chadcn--sonner` controller and `app/assets/tailwind/chadcn/sonner.css` do what the sonner library does):

```ruby
# layout: the flash is shown as toasts (notice and success -> success, alert and error -> error, warning, info, anything else plain)
render Chadcn::Toaster.new(flash: { notice: "Saved", alert: "Could not send" }, close_button: true, position: "top-center")

# any server response: a Turbo Stream appends a toast to the Toaster's id ("toaster" unless you pass id:)
Chadcn::Sonner::Toast.new(type: :success, title: "Saved", description: "All changes stored", action: { label: "Undo", event: "undo" })
```

```javascript
// any script: the same function as sonner's toast
window.Toaster.success("Saved", { description: "All changes stored", action: { label: "Undo", onClick: () => {} } })
window.Toaster.promise(fetch("/save"), { loading: "Saving", success: "Saved", error: "Failed" })
document.dispatchEvent(new CustomEvent("chadcn--sonner:show", { detail: { message: "Hello", type: "info" } }))
```

In a Rails controller, `turbo_stream.append "toaster", Chadcn::Sonner::Toast.new(type: :success, title: "Saved")` renders the
`<template data-chadcn--sonner-toast>` the Toaster turns into a toast. Titles and descriptions are text, never markup. Types:
`default` (no icon), `success`, `info`, `warning`, `error`, `loading` (no timer until it is updated). A toast with the same `id`
updates instead of stacking.

- The `<section>` is an `aria-live="polite"` region labelled `Notifications alt+T` (the hotkey, `hotkey:`, expands the stack and focuses
  it; Escape collapses it). An `error` toast is also written to a hidden `role="alert"` element so it interrupts.
- Toasts pause while the stack is hovered, focused or expanded and when the tab is hidden; a swipe towards the edge of `position:`
  dismisses; `dismissible: false` stops swipe, close button and cancel.
- Events on the section: `chadcn--sonner:dismiss`, `:auto-close`, `:action` and `:cancel` (`detail.id`, and `detail.name` for the toast's `event:`).
  An action with `href:` visits that http(s) URL.
- With `data: { turbo_permanent: true }` the Toaster survives Turbo visits (and its toasts stay), but then a page that renders `flash:`
  is not re-read: send the flash as a Turbo Stream instead. Without it, toasts disappear with the page, and a Turbo cache snapshot never
  contains them.
- `toast_options: { class_names: { toast: "...", error: "..." } }`, `class:` (added to the lists) and `style:` customise the look; the
  colors come from the theme (`--popover`, `--popover-foreground`, `--border`, `--radius`).

## Notes

- `Avatar::Image` ships its `<img>` in an inert `<template>` and the `chadcn--avatar` controller mounts it once it has loaded (Radix
  `Avatar.Image` semantics, event `chadcn--avatar:loading-status-change`); `Avatar::Fallback` shows meanwhile, after `delay_ms:` when given.
- `Badge`, `Item`, `Marker` and `Empty::Media` expose `.variants(...)` returning the class string, like React's cva helpers, to
  style another element the same way.
- `Progress` renders the Radix progressbar DOM (`role="progressbar"`, `aria-valuemin` / `aria-valuemax`, `data-state`, `data-max`; no
  `aria-valuenow`, like shadcn) with the indicator translated by `value:` out of `max:`.
