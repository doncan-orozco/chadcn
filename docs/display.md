# Display components

Static building blocks: no Stimulus controller is needed except for `Avatar` (image loading state). Conventions shared by every
component: [api-conventions.md](api-conventions.md).

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
| `Table` | none (attributes go to the inner `<table>`; the scroll container is fixed) | `Header` `table.header`, `Body` `table.body`, `Footer` `table.footer`, `Row` `table.row`, `Head` `table.head`, `Cell` `table.cell`, `Caption` `table.caption` |
| `Item` | `variant:` (`default`, `outline`, `muted`), `size:` (`default`, `sm`), `as_child:`; `Item.variants` | `Media` (`variant:`) `item.media`, `Content` `item.content`, `Actions` `item.actions`, `Group` `item.group`, `Title` `item.title`, `Description` `item.description`, `Header` `item.header`, `Footer` `item.footer`, `Separator` `item.separator` |
| `Attachment` | `state:` (`idle`, `uploading`, `processing`, `error`, `done`), `size:` (`default`, `sm`, `xs`), `orientation:` (`horizontal`, `vertical`) | `Group` `attachment.group`, `Media` (`variant:`) `attachment.media`, `Content` `attachment.content`, `Title` `attachment.title`, `Description` `attachment.description`, `Actions` `attachment.actions`, `Action` (`variant:`, `size:`) `attachment.action`, `Trigger` (`as_child:`, `type:`) `attachment.trigger` |

The exact accepted values of every option are the keys of the component's `VARIANTS` / `SIZES` tables in the YARD documentation;
passing a symbol (`variant: :destructive`) is the same as the string.

## Example: a card, both forms

```ruby
# explicit classes
render Phlex::Shadcn::Card.new(class: "w-full max-w-sm") do
  render Phlex::Shadcn::Card::Header.new do
    render Phlex::Shadcn::Card::Title.new { "Login to your account" }
    render Phlex::Shadcn::Card::Description.new { "Enter your email below to login to your account" }
    render Phlex::Shadcn::Card::Action.new { render Phlex::Shadcn::Button.new(variant: "link") { "Sign Up" } }
  end
  render Phlex::Shadcn::Card::Content.new { render Phlex::Shadcn::Input.new(type: "email", placeholder: "m@example.com") }
  render Phlex::Shadcn::Card::Footer.new(class: "flex-col gap-2") do
    render Phlex::Shadcn::Button.new(type: "submit", class: "w-full") { "Login" }
  end
end

# generated helpers
render Phlex::Shadcn::Card.new(class: "w-full max-w-sm") do |card|
  card.header do
    card.title { "Login to your account" }
    card.description { "Enter your email below to login to your account" }
    card.action { render Phlex::Shadcn::Button.new(variant: "link") { "Sign Up" } }
  end
  card.content { render Phlex::Shadcn::Input.new(type: "email", placeholder: "m@example.com") }
  card.footer(class: "flex-col gap-2") { render Phlex::Shadcn::Button.new(type: "submit", class: "w-full") { "Login" } }
end
```

## Example: a table

```ruby
render Phlex::Shadcn::Table.new do |table|
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

## Notes

- `Avatar::Image` ships its `<img>` in an inert `<template>` and the `shadcn--avatar` controller mounts it once it has loaded (Radix
  `Avatar.Image` semantics, event `shadcn--avatar:loading-status-change`); `Avatar::Fallback` shows meanwhile, after `delay_ms:` when given.
- `Badge`, `Item`, `Marker` and `Empty::Media` expose `.variants(...)` returning the class string, like React's cva helpers, to
  style another element the same way.
- `Progress` renders the Radix progressbar DOM (`role="progressbar"`, `aria-valuemin` / `aria-valuemax`, `data-state`, `data-max`; no
  `aria-valuenow`, like shadcn) with the indicator translated by `value:` out of `max:`.
