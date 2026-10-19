# Disclosure and navigation

Accordion, collapsible, tabs, breadcrumb, pagination, navigation menu, sidebar, scroll area and the direction provider. Controllers:
`shadcn--accordion`, `shadcn--collapsible`, `shadcn--tabs`, `shadcn--navigation-menu`, `shadcn--sidebar`, `shadcn--scroll-area`.
Conventions: [api-conventions.md](api-conventions.md).

| Component | Root kwargs (besides `**attrs`) | Parts (class and generated helper) | Events |
|---|---|---|---|
| `Accordion` | `type:` (`single`, `multiple`), `value:`, `default_value:`, `collapsible:`, `disabled:`, `dir:`, `orientation:`, `as_child:` | `Item` (`value:`, `disabled:`) `accordion.item`, `Trigger` `accordion.trigger`, `Content` `accordion.content` | `value-change` |
| `Collapsible` | `open:`, `default_open:`, `disabled:`, `as_child:` | `Trigger` `collapsible.trigger`, `Content` `collapsible.content` | `open-change` |
| `Tabs` | `value:`, `default_value:`, `orientation:` (`horizontal`, `vertical`), `dir:`, `activation_mode:` (`automatic`, `manual`), `as_child:` | `List` `tabs.list`, `Trigger` (`value:`, `disabled:`) `tabs.trigger`, `Content` (`value:`, `force_mount:`) `tabs.content` | `value-change` |
| `Breadcrumb` | none | `List` `breadcrumb.list`, `Item` `breadcrumb.item`, `Link` (`as_child:`) `breadcrumb.link`, `Page` `breadcrumb.page`, `Separator` `breadcrumb.separator`, `Ellipsis` (`label:` "More") `breadcrumb.ellipsis` | |
| `Pagination` | none | `Content` `pagination.content`, `Item` `pagination.item`, `Link` (`is_active:`, `size:`) `pagination.link`, `Previous` (`label:` "Previous", `aria_label:` "Go to previous page") `pagination.previous`, `Next` (`label:` "Next", `aria_label:` "Go to next page") `pagination.next`, `Ellipsis` (`label:` "More pages") `pagination.ellipsis` | |
| `NavigationMenu` | `viewport:` (true), `value:`, `default_value:`, `delay_duration:` (200), `skip_delay_duration:` (300), `orientation:`, `dir:`, `activation_mode:` | `List` (`as_child:`) `navigation_menu.list`, `Item` (`value:`, `as_child:`) `navigation_menu.item`, `Trigger` (`disabled:`) `navigation_menu.trigger`, `Content` (`force_mount:`, `as_child:`) `navigation_menu.content`, `Viewport` (`force_mount:`) `navigation_menu.viewport`, `Link` (`active:`, `as_child:`) `navigation_menu.link`, `Indicator` (`force_mount:`) `navigation_menu.indicator`; `NavigationMenu.trigger_style` | `value-change`, `link-select` |
| `Sidebar` | `side:` (`left`, `right`), `variant:` (`sidebar`, `floating`, `inset`), `collapsible:` (`offcanvas`, `icon`, `none`), `mobile_title:` ("Sidebar"), `mobile_description:` (nil: "Displays the mobile sidebar.") | `Provider` (`default_open:`, `open:`, `style:`) `sidebar.provider`, `Trigger` (`variant:`, `size:`, `label:` "Toggle Sidebar") `sidebar.trigger`, `Rail` `sidebar.rail`, `Inset` `sidebar.inset`, `Input` `sidebar.input`, `Header` `sidebar.header`, `Footer` `sidebar.footer`, `Separator` `sidebar.separator`, `Content` `sidebar.content`, `Group` `sidebar.group`, `GroupLabel` `sidebar.group_label`, `GroupAction` `sidebar.group_action`, `GroupContent` `sidebar.group_content`, `Menu` `sidebar.menu`, `MenuItem` `sidebar.menu_item`, `MenuButton` (`is_active:`, `variant:`, `size:`, `tooltip:`, `as_child:`; `MenuButton.variants`) `sidebar.menu_button`, `MenuAction` (`show_on_hover:`) `sidebar.menu_action`, `MenuBadge` `sidebar.menu_badge`, `MenuSkeleton` (`show_icon:`) `sidebar.menu_skeleton`, `MenuSub` `sidebar.menu_sub`, `MenuSubItem` `sidebar.menu_sub_item`, `MenuSubButton` (`size:`, `is_active:`, `as_child:`) `sidebar.menu_sub_button` | `open-change`, `open-mobile-change` |
| `ScrollArea` | `type:` (`hover`, `scroll`, `auto`, `always`), `dir:`, `scroll_hide_delay:` (600) | `ScrollBar` (`orientation:`, `force_mount:`) `scroll_area.scroll_bar` | |
| `Direction` | namespace; `Direction.use_direction(context, local_dir = nil)` | `Provider` (`dir:` or `direction:`, `ltr` / `rtl`) `direction.provider`; `Direction::Consumer` mixin for your own parts | |

## Example: accordion and tabs, both forms

```ruby
# explicit classes
render Phlex::Shadcn::Accordion.new(type: "single", collapsible: true, default_value: "item-1", class: "w-full") do
  render Phlex::Shadcn::Accordion::Item.new(value: "item-1") do
    render Phlex::Shadcn::Accordion::Trigger.new { "Product Information" }
    render Phlex::Shadcn::Accordion::Content.new(class: "flex flex-col gap-4 text-balance") { p { "..." } }
  end
end

# generated helpers
render Phlex::Shadcn::Accordion.new(type: "single", collapsible: true, default_value: "item-1", class: "w-full") do |accordion|
  accordion.item(value: "item-1") do
    accordion.trigger { "Product Information" }
    accordion.content(class: "flex flex-col gap-4 text-balance") { p { "..." } }
  end
end

render Phlex::Shadcn::Tabs.new(default_value: "account", class: "w-[400px]") do |tabs|
  tabs.list do
    tabs.trigger(value: "account") { "Account" }
    tabs.trigger(value: "password") { "Password" }
  end
  tabs.content(value: "account") { "Make changes to your account here." }
  tabs.content(value: "password") { "Change your password here." }
end
```

## Example: breadcrumb and pagination

```ruby
render Phlex::Shadcn::Breadcrumb.new do |breadcrumb|
  breadcrumb.list do
    breadcrumb.item { breadcrumb.link(href: "/") { "Home" } }
    breadcrumb.separator
    breadcrumb.item { breadcrumb.link(as_child: :a, href: "/docs") { "Docs" } }
    breadcrumb.separator
    breadcrumb.item { breadcrumb.page { "Breadcrumb" } }
  end
end

render Phlex::Shadcn::Pagination.new do |pagination|
  pagination.content do
    pagination.item { pagination.previous(href: "?page=1") }
    pagination.item { pagination.link(href: "?page=2", is_active: true) { "2" } }
    pagination.item { pagination.ellipsis }
    pagination.item { pagination.next(href: "?page=3") }
  end
end
```

## Example: sidebar layout

```ruby
render Phlex::Shadcn::Sidebar::Provider.new do
  render Phlex::Shadcn::Sidebar.new(collapsible: "icon") do |sidebar|
    sidebar.header { sidebar.menu { sidebar.menu_item { sidebar.menu_button(size: "lg") { "Acme Inc" } } } }
    sidebar.content do
      sidebar.group do
        sidebar.group_label { "Platform" }
        sidebar.group_content do
          sidebar.menu do
            sidebar.menu_item do
              sidebar.menu_button(as_child: :a, href: "/inbox", is_active: true, tooltip: "Inbox") do
                render Phlex::Shadcn::Icon.new("inbox")
                span { "Inbox" }
              end
              sidebar.menu_badge { "24" }
            end
          end
        end
      end
    end
    sidebar.rail
  end
  render Phlex::Shadcn::Sidebar::Inset.new do
    header(class: "flex h-16 items-center gap-2 px-4") { render Phlex::Shadcn::Sidebar::Trigger.new }
    main { "..." }
  end
end
```

`Sidebar::Provider` owns the open state (cookie `sidebar_state`, keyboard shortcut `Ctrl/Cmd+B`, the mobile sheet) and renders the
CSS variables; `Sidebar::Trigger` and `Sidebar::Rail` toggle it from anywhere inside the provider.

## Notes

- `Tabs` normalizes `activation_mode:` (`:manual` and `"manual"` are equal); `NavigationMenu` forwards it as given, and an unknown
  `orientation:` falls back to horizontal, like the React component.
- `Direction::Provider` sets the direction (`rtl`) its descendants read; without `dir:` or `direction:` it keeps the direction of the
  enclosing provider (React resets to `ltr`); components never read the document `dir`, exactly as Radix.
  Your own parts get it by including `Phlex::Shadcn::Direction::Consumer` (private `use_direction`) or calling
  `Phlex::Shadcn::Direction.use_direction(context)`.
- `ScrollArea` renders the viewport and the scrollbars Radix renders (`type: "hover"` shows them while hovering and hides them after
  `scroll_hide_delay:` ms).
