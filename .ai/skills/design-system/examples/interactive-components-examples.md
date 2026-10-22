# Interactive Components Examples

Current examples for interactive components where required Stimulus bindings are component defaults.

## Rule

Do not repeat required `controller`, `target`, or mandatory `action` bindings in views when the component already injects them.

## Switch

```ruby
render Components::Ui::Switch.new(id: "notifications", checked: true) do |switch|
  switch.thumb
end
```

Notes:
- Parent injects default `ui--switch` controller and toggle/keydown actions.
- `checked:` maps to `ui__switch_checked_value` when caller has not set it.
- `switch.thumb` injects `ui__switch_target: "thumb"`.

## Tabs

```ruby
render Components::Ui::Tabs.new(data: { ui__tabs_active_index_value: 0 }) do |tabs|
  tabs.list do
    tabs.trigger { "Account" }
    tabs.trigger { "Password" }
  end

  tabs.content { "Account content" }
  tabs.content { "Password content" }
end
```

Notes:
- Parent injects `data-controller="ui--tabs"`.
- `tabs.trigger` injects required trigger target and actions.
- `tabs.content` injects required content target.

## Select

```ruby
render Components::Ui::Select.new(
  placeholder: "Select a fruit"
) do |select|
  select.trigger do
    select.value
    render Components::Ui::Icon.new(:"chevron-down", source: :lucide, class: "h-4 w-4 opacity-50")
  end

  select.content(hidden: true) do
    select.item(value: "apple", tabindex: "0") { "Apple" }
    select.item(value: "banana", tabindex: "0") { "Banana" }
  end
end
```

Notes:
- `Select` injects default `ui--select` controller.
- `select.trigger` injects required trigger target and toggle/navigate actions.
- `select.content` injects required content target.
- `select.item` injects required item target and select action.
- `select.value` injects required value-display target.

## Tooltip

```ruby
render Components::Ui::TooltipProvider.new do |provider|
  provider.tooltip(delay: 200, class: "inline-block") do |tooltip|
    tooltip.trigger do
      render Components::Ui::Button.new(variant: :outline) { "Hover me" }
    end

    tooltip.content(hidden: true) { "This is a tooltip" }
  end
end
```

Notes:
- `Tooltip` injects default `ui--tooltip` controller.
- `delay:` maps to `ui__tooltip_delay_value` when caller has not set it.
- `tooltip.trigger` injects required trigger target and hover/focus actions.
- `tooltip.content` injects required content target.

## Popover

```ruby
render Components::Ui::Popover.new do |popover|
  popover.trigger do
    render Components::Ui::Button.new(variant: :outline) { "Open popover" }
  end

  popover.content(hidden: true, class: "w-80") do
    div(class: "space-y-2") do
      h4(class: "font-medium") { "Dimensions" }
      p(class: "text-sm text-muted-foreground") { "Width: 100%" }
    end
  end
end
```

Notes:
- `Popover` injects default `ui--popover` controller and `ui__popover_open_value: false`.
- `popover.trigger` injects the required trigger target and toggle action.
- `popover.content` injects the required content target.

## HoverCard

```ruby
render Components::Ui::HoverCard.new(delay: 150) do |hover_card|
  hover_card.trigger do
    render Components::Ui::Button.new(variant: :outline) { "Hover for preview" }
  end

  hover_card.content(hidden: true, class: "w-80") do
    div(class: "space-y-2") do
      p(class: "text-sm font-semibold") { "@nextjs" }
      p(class: "text-sm text-muted-foreground") { "The React Framework." }
    end
  end
end
```

Notes:
- `HoverCard` injects default `ui--hover-card` controller and `ui__hover_card_open_value: false`.
- `hover_card.trigger` injects the required trigger target plus hover/focus show-hide actions.
- `hover_card.content` injects the required content target plus hover/focus show-hide actions so the card stays open while it is being interacted with.

## Dialog

```ruby
render Components::Ui::Dialog.new do |dialog|
  dialog.trigger do
    render Components::Ui::Button.new(variant: :outline) { "Open Dialog" }
  end

  dialog.content(hidden: true) do
    dialog.header do
      dialog.title { "Confirm Action" }
      dialog.description { "This action cannot be undone." }
    end

    dialog.footer(class: "mt-4") do
      render Components::Ui::Button.new(variant: :outline, data: { action: "click->ui--dialog#close" }) { "Cancel" }
      render Components::Ui::Button.new(data: { action: "click->ui--dialog#close" }) { "Continue" }
    end
  end
end
```

Notes:
- `Dialog` injects default `ui--dialog` controller and `ui__dialog_open_value: false`.
- `dialog.trigger` injects required open action.
- `dialog.content` injects content target and renders overlay internally.

## AlertDialog

```ruby
render Components::Ui::AlertDialog.new do |dialog|
  dialog.trigger do
    render Components::Ui::Button.new(variant: :destructive) { "Delete" }
  end

  dialog.content(hidden: true) do
    dialog.header do
      dialog.title { "Are you absolutely sure?" }
      dialog.description { "This action cannot be undone." }
    end

    dialog.footer(class: "mt-4") do
      dialog.cancel { "Cancel" }
      dialog.action { "Continue" }
    end
  end
end
```

Notes:
- `AlertDialog` injects default `ui--dialog` controller and `ui__dialog_open_value: false`.
- `alert_dialog.trigger` injects required open action.
- `alert_dialog.content` injects content target and renders overlay internally.
- `alert_dialog.cancel` and `alert_dialog.action` inject close actions.

## Sheet

```ruby
render Components::Ui::Sheet.new do |sheet|
  sheet.trigger do
    render Components::Ui::Button.new(variant: :outline) { "Open Sheet" }
  end

  sheet.content(hidden: true, side: :right) do
    sheet.header do
      sheet.title { "Sheet Title" }
      sheet.description { "This is a sheet description" }
    end

    sheet.footer(class: "mt-4") do
      render Components::Ui::Button.new(variant: :outline, data: { action: "click->ui--dialog#close" }) { "Cancel" }
      render Components::Ui::Button.new(data: { action: "click->ui--dialog#close" }) { "Save" }
    end
  end
end
```

Notes:
- `Sheet` injects default `ui--dialog` controller and `ui__dialog_open_value: false`.
- `sheet.trigger` injects required open action.
- `sheet.content` injects content target + slide transition and renders overlay target internally.

## Dropdown Menu

```ruby
render Components::Ui::DropdownMenu.new(
  data: { ui__dropdown_placement_value: "bottom-end" }
) do |dropdown|
  dropdown.trigger(variant: :ghost, size: :icon, class: "size-8") do
    render Components::Ui::Icon.new(:"more-horizontal", class: "h-4 w-4")
  end

  dropdown.content(hidden: true, align: :end) do
    dropdown.item(href: "/edit") { "Edit" }
    dropdown.separator
    dropdown.item(href: "/delete", variant: :destructive, data: { turbo_method: :delete }) { "Delete" }
  end
end
```

Notes:
- `DropdownMenu` injects default controller.
- `trigger`, `content`, and `item` inject required targets/actions and merge caller data.
