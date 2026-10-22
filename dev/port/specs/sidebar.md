# Sidebar (shadcn new-york-v4)

Oracle: `dev/port/oracle/src/sidebar.tsx` (source_sha `2ba1a9b9422f4172`, cited as `tsx:<line>`), manifest `oracle/manifest/sidebar.json`, hook `dev/react-shadcn-catalog/src/hooks/use-mobile.ts` (`mobile:<line>`). Tier `client`: the only Radix import is `Slot` (`radix-ui` 1.7.0, `@radix-ui/react-slot` 1.4.0, `slot:<line>`); all overlay behavior comes from the composed `Sheet` (Radix Dialog, see `specs/sheet.md`) and `Tooltip` (Radix Tooltip 1.3.0, `tooltip:<line>`, see `specs/tooltip.md`). Lines re-checked here: `react-dialog/dist/index.mjs` (`dialog:`), `react-focus-scope/dist/index.mjs` (`fs:`). Icons: `lucide-react` 0.577.0.

Examples (all fetched from `https://ui.shadcn.com/r/styles/new-york-v4/<name>.json`, type `registry:internal`): `sidebar-demo`, `sidebar-header`, `sidebar-footer`, `sidebar-group`, `sidebar-group-collapsible`, `sidebar-group-action`, `sidebar-menu`, `sidebar-menu-action`, `sidebar-menu-sub`, `sidebar-menu-collapsible`, `sidebar-menu-badge`, `sidebar-rsc`, `sidebar-controlled`. The `sidebar-01`..`sidebar-16` items are `registry:block` page layouts composed with components the sidebar manifest does not depend on (breadcrumb, dropdown-menu, collapsible, avatar, calendar...), so they are covered through the parts they use, not as scenarios. Substitutions in example scenarios (scenario_coverage only allows sidebar + dependency exports): `DropdownMenu*` is dropped and its trigger state is not simulated except where the class under test needs it (`data-state="open"` passed as a prop); `Collapsible` / `CollapsibleContent` become `_div` with the `group/collapsible` class and `data-state`; `CollapsibleTrigger` becomes `_button`; `Toaster`/`toast` is dropped; `React.Suspense` in `sidebar-rsc` renders its fallback.

## API

Every part: `class:` goes through `cn` last (tailwind_merge, caller wins), `**attrs` pass through (`data:` / `aria:` deep-merged; because every source spreads `{...props}` AFTER its own attributes, a caller `data: { slot: }`, `data: { sidebar: }`, `title:`, `tabindex:`... overrides the component value), string and symbol option values accepted (`variant: :floating` == `"floating"`), `nil` = default. Unknown option values raise `ArgumentError` (TS unions forbid them). Parts built on `Slot.Root` accept `as_child:` (`false` | tag symbol | `Components::V2::*` instance), implemented by `Components::V2::Base#render_as_child` (Radix `mergeProps`: child wins, class plain join slot-first, `style` merged, `data-controller` unioned, `data-action` child first).

| React (sidebar.tsx) | Ruby | Notes |
|---|---|---|
| `SidebarProvider` (tsx:56-152; `defaultOpen = true`, `open`, `onOpenChange`, `className`, `style`, `...props` on the wrapper div) | `Components::V2::Sidebar::Provider.new(default_open: true, open: nil, class: nil, style: nil, **attrs) { ... }` | `open:` true/false = controlled (tsx:75 `openProp ?? _open`): the controller never changes its own desktop state, it dispatches `open-change` (and still writes the cookie, tsx:86); callers update `data-chadcn--sidebar-open-value`. `open: nil` = uncontrolled from `default_open`. `style:` Hash (`{ "--sidebar-width" => "20rem" }`) or String, merged AFTER the component vars (tsx:136-138, caller wins). The Provider does NOT read the cookie (the oracle never reads it); callers do, as in the shadcn docs: `default_open: cookies[:sidebar_state] == "true"`. Booleans only (no `"true"` strings). |
| `Sidebar` (tsx:154-254; `side = "left"`, `variant = "sidebar"`, `collapsible = "offcanvas"`) | `Components::V2::Sidebar.new(side: "left", variant: "sidebar", collapsible: "offcanvas", class: nil, **attrs) { ... }` | `side:` `"left" \| "right"`, `variant:` `"sidebar" \| "floating" \| "inset"`, `collapsible:` `"offcanvas" \| "icon" \| "none"`. Where `class:`/`**attrs` land depends on the mode (see Structure): `none` -> the single div; desktop -> `sidebar-container` (NOT the outer `sidebar` div); mobile -> Sheet Root, i.e. dropped from the DOM (tsx:185 `<Sheet ... {...props}>`). |
| `SidebarTrigger` (tsx:256-280; `ComponentProps<typeof Button>`) | `Components::V2::Sidebar::Trigger.new(variant: "ghost", size: "icon", class: nil, **attrs)` | Renders `Components::V2::Button.new(variant:, size:, class: cn("size-7", class), data: { sidebar: "trigger", slot: "sidebar-trigger" }, **attrs)`. Because `{...props}` is spread after `variant="ghost" size="icon"` (tsx:267-274), caller `variant:`/`size:` win (Button options, e.g. `size: "icon-sm"`). No block: the oracle's JSX children (icon + sr-only) replace any `children` prop, so a given block is ignored. No `as_child:`: Button's Slot would receive two children and throw (slot:38-47), so `as_child:` raises `ArgumentError`. Click: caller handlers first (`data: { action: }` descriptors kept before), then `toggleSidebar` (tsx:270-273, no `defaultPrevented` check). |
| `SidebarRail` (tsx:282-305) | `Components::V2::Sidebar::Rail.new(class: nil, **attrs) { optional children }` | `<button>` self-closing in JSX, so a `children` prop (block) does render. `aria-label`, `tabIndex`, `title` precede `{...props}` and can be overridden. |
| `SidebarInset` (tsx:307-319) | `Components::V2::Sidebar::Inset.new(class: nil, **attrs) { ... }` | `main`. |
| `SidebarInput` (tsx:321-333; `ComponentProps<typeof Input>`) | `Components::V2::Sidebar::Input.new(type: nil, class: nil, **attrs)` | Renders `Components::V2::Input.new(type:, class: cn("h-8 w-full bg-background shadow-none", class), data: { slot: "sidebar-input", sidebar: "input" }, **attrs)`; Input spreads props after its own `data-slot`, so `data-slot="sidebar-input"` wins. |
| `SidebarHeader` / `SidebarFooter` / `SidebarContent` / `SidebarGroup` / `SidebarGroupContent` (tsx:335-355, 371-394, 440-452) | `Components::V2::Sidebar::Header` / `::Footer` / `::Content` / `::Group` / `::GroupContent` `.new(class: nil, **attrs) { ... }` | plain `div`s. |
| `SidebarSeparator` (tsx:357-369; `ComponentProps<typeof Separator>`) | `Components::V2::Sidebar::Separator.new(orientation: "horizontal", decorative: true, as_child: false, class: nil, **attrs)` | Renders `Components::V2::Separator.new(orientation:, decorative:, as_child:, class: cn("mx-2 w-auto bg-sidebar-border", class), data: { slot: "sidebar-separator", sidebar: "separator" }, **attrs)` (Separator options per `specs/separator.md`). |
| `SidebarGroupLabel` (tsx:396-415; `asChild = false`) | `Components::V2::Sidebar::GroupLabel.new(as_child: false, class: nil, **attrs) { ... }` | `div`, or the child with `as_child:`. |
| `SidebarGroupAction` (tsx:417-438) | `Components::V2::Sidebar::GroupAction.new(as_child: false, class: nil, **attrs) { ... }` | `button` with no `type` attribute (React adds none). |
| `SidebarMenu` / `SidebarMenuItem` (tsx:454-474) | `Components::V2::Sidebar::Menu` (`ul`) / `::MenuItem` (`li`) `.new(class: nil, **attrs) { ... }` | |
| `SidebarMenuButton` (tsx:498-546; `asChild = false`, `isActive = false`, `variant = "default"`, `size = "default"`, `tooltip`) | `Components::V2::Sidebar::MenuButton.new(as_child: false, is_active: false, variant: "default", size: "default", tooltip: nil, class: nil, **attrs) { ... }` | `variant:` `"default" \| "outline"`, `size:` `"default" \| "sm" \| "lg"` (cva keys, tsx:480-489). `tooltip:` `nil` \| String \| Hash. A String becomes `{ children: string }` (tsx:529-533). A Hash holds `Components::V2::Tooltip::Content` kwargs/attrs plus `children:` (String rendered as the content text) and `class:`; it is splatted AFTER the defaults `side: "right", align: "center", hidden: <computed>` (tsx:538-543), so a caller `hidden: false` or `side: "bottom"` wins. `is_active:` Boolean. |
| `sidebarMenuButtonVariants` (not exported, tsx:476-496) | `Components::V2::Sidebar::MenuButton.variants(variant: "default", size: "default")` | Class method returning the cva string (api-mapping "class-level table"); used internally, same keys. |
| `SidebarMenuAction` (tsx:548-578; `asChild = false`, `showOnHover = false`) | `Components::V2::Sidebar::MenuAction.new(as_child: false, show_on_hover: false, class: nil, **attrs) { ... }` | `button`, no `type`. |
| `SidebarMenuBadge` (tsx:580-600) | `Components::V2::Sidebar::MenuBadge.new(class: nil, **attrs) { ... }` | `div`. |
| `SidebarMenuSkeleton` (tsx:602-638; `showIcon = false`) | `Components::V2::Sidebar::MenuSkeleton.new(show_icon: false, class: nil, **attrs)` | Width is random per render (see Structure and Deviations). |
| `SidebarMenuSub` / `SidebarMenuSubItem` (tsx:640-667) | `Components::V2::Sidebar::MenuSub` (`ul`) / `::MenuSubItem` (`li`) `.new(class: nil, **attrs) { ... }` | |
| `SidebarMenuSubButton` (tsx:669-699; `asChild = false`, `size = "md"`, `isActive = false`) | `Components::V2::Sidebar::MenuSubButton.new(as_child: false, size: "md", is_active: false, class: nil, **attrs) { ... }` | `a` (with no `href` unless given). `size:` `"sm" \| "md"`. |
| `useSidebar` (tsx:47-54) | server: `Components::V2::Sidebar.use_sidebar(component)` ; client: the `chadcn--sidebar` controller | Server: returns a frozen value object `state` (`"expanded"`/`"collapsed"`), `open`, `open_mobile` (`false`), `is_mobile` (`false`: the server cannot know, and React's first render is also `false`, mobile:6 + 18 `!!undefined`), read from the Phlex render context set by the nearest `Sidebar::Provider`. Raises `ArgumentError, "useSidebar must be used within a SidebarProvider."` outside one (tsx:49-51). `Sidebar`, `Sidebar::Trigger`, `Sidebar::Rail` and `Sidebar::MenuButton` call it and therefore raise outside a Provider (tsx:166, 261, 283, 512); every other part works standalone. Client: `toggleSidebar` = action `chadcn--sidebar#toggle`; `setOpen` = `chadcn--sidebar#setOpen` with `data-chadcn--sidebar-open-param`; `setOpenMobile` = `chadcn--sidebar#setOpenMobile` (same param); state is observable as `data-state`/`data-collapsible` on `[data-slot=sidebar]` and through the events. |

Events (dispatched with `this.dispatch` on the Provider wrapper, bubbling, prefix `chadcn--sidebar:`):

| Event | Origin | detail | When |
|---|---|---|---|
| `open-change` | `onOpenChange` (`setOpenProp`, tsx:79-80) | `{ open }` | every desktop `setOpen` (trigger, rail, shortcut on desktop, `setOpen` action), in controlled and uncontrolled mode. |
| `open-mobile-change` | none in React (`setOpenMobile` is internal state, tsx:70) | `{ open }` | every mobile open/close; informational only, no DOM equivalent (React exposes it only through `useSidebar`). |

`ref` has no equivalent. Example (sidebar-demo):

```ruby
render Components::V2::Sidebar::Provider.new do
  render Components::V2::Sidebar.new do
    render Components::V2::Sidebar::Content.new do
      render Components::V2::Sidebar::Group.new do
        render Components::V2::Sidebar::GroupLabel.new { "Application" }
        render Components::V2::Sidebar::GroupContent.new do
          render Components::V2::Sidebar::Menu.new do
            render Components::V2::Sidebar::MenuItem.new do
              render Components::V2::Sidebar::MenuButton.new(as_child: :a, href: "#") do
                render Components::V2::Icon.new(name: "house")
                span { "Home" }
              end
            end
          end
        end
      end
    end
  end
  render Components::V2::Sidebar::Inset.new do
    header(class: "flex h-12 items-center justify-between px-4") { render Components::V2::Sidebar::Trigger.new }
  end
end
```

## Structure

Class strings are verbatim from the oracle (order irrelevant; set equality after `cn` is the gate). Where a part goes through `cn`, tailwind_merge must resolve conflicts exactly like tailwind-merge v3 (including the postfix `!` important modifier: `group-data-[collapsible=icon]:p-0!` of `lg` removes the base `group-data-[collapsible=icon]:p-2!`; `text-xs` of `sm` removes the base `text-sm`; Trigger `size-7` removes Button `size-9`; Input `h-8`/`bg-background`/`shadow-none` remove `h-9`/`bg-transparent`/`shadow-xs`; Sheet `w-(--sidebar-width)`/`bg-sidebar`/`p-0` remove `w-3/4`/`bg-background`).

### Provider (`sidebar-wrapper`)

```html
<div data-slot="sidebar-wrapper" style="--sidebar-width: 16rem; --sidebar-width-icon: 3rem; {caller style}"
     class="{cn('group/sidebar-wrapper flex min-h-svh w-full has-data-[variant=inset]:bg-sidebar', class)}" {attrs}
     data-controller="chadcn--sidebar" data-chadcn--sidebar-open-value data-chadcn--sidebar-controlled-value data-chadcn--sidebar-open-mobile-value>
  {block}
</div>
```

- Constants verbatim (tsx:28-33): `SIDEBAR_WIDTH = "16rem"`, `SIDEBAR_WIDTH_ICON = "3rem"`, `SIDEBAR_WIDTH_MOBILE = "18rem"`, `SIDEBAR_COOKIE_NAME = "sidebar_state"`, `SIDEBAR_COOKIE_MAX_AGE = 60 * 60 * 24 * 7` (604800), `SIDEBAR_KEYBOARD_SHORTCUT = "b"`; `MOBILE_BREAKPOINT = 768` (mobile:3). They are Ruby/JS constants, not kwargs or Stimulus values (the oracle exposes none of them as props).
- The wrapper has NO `data-state` (the manifest's `data-state: expanded` under `SidebarProvider` is the extractor reading `const state = open ? ...` at tsx:114; the attribute is rendered by `Sidebar`, not here).
- `TooltipProvider delayDuration={0}` (tsx:131) renders no element: the Provider renders `Components::V2::Tooltip::Provider.new(delay_duration: 0)` around the wrapper div, so every `Sidebar::MenuButton` tooltip gets a provider (Tooltip raises without one).
- The wrapper is the `chadcn--sidebar` Stimulus host (it is a real element in the oracle, so no deviation is needed for the host).

### Sidebar, `collapsible: "none"` (tsx:168-181)

```html
<div data-slot="sidebar" class="{cn('flex h-full w-(--sidebar-width) flex-col bg-sidebar text-sidebar-foreground', class)}" {attrs}>{block}</div>
```
No `data-state`, `data-side`, `data-variant`, `data-collapsible`; `side`/`variant` have no effect. Rendered the same on mobile (the `none` branch returns before the `isMobile` check).

### Sidebar, desktop (tsx:208-253), server-rendered

```html
<div class="group peer hidden text-sidebar-foreground md:block" data-state="expanded|collapsed"
     data-collapsible="" | "offcanvas|icon" data-variant="{variant}" data-side="{side}" data-slot="sidebar"
     data-chadcn--sidebar-target="sidebar">
  <div data-slot="sidebar-gap" class="{gap}"></div>
  <div data-slot="sidebar-container" class="{container}" {attrs}>
    <div data-sidebar="sidebar" data-slot="sidebar-inner" class="flex h-full w-full flex-col bg-sidebar group-data-[variant=floating]:rounded-lg group-data-[variant=floating]:border group-data-[variant=floating]:border-sidebar-border group-data-[variant=floating]:shadow-sm">{block}</div>
  </div>
</div>
<template data-chadcn--sidebar-target="mobile">{mobile Sheet markup, see below}</template>
```

- Outer `sidebar` div: fixed class string (no `cn`, no caller class). `data-collapsible` is `""` (attribute present, empty) while expanded and equals `collapsible` while collapsed (tsx:212). `data-state` from the Provider state (tsx:114).
- `gap` = `cn("relative w-(--sidebar-width) bg-transparent transition-[width] duration-200 ease-linear", "group-data-[collapsible=offcanvas]:w-0", "group-data-[side=right]:rotate-180", floating|inset ? "group-data-[collapsible=icon]:w-[calc(var(--sidebar-width-icon)+(--spacing(4)))]" : "group-data-[collapsible=icon]:w-(--sidebar-width-icon)")` (tsx:220-227).
- `container` = `cn("fixed inset-y-0 z-10 hidden h-svh w-(--sidebar-width) transition-[left,right,width] duration-200 ease-linear md:flex", left ? "left-0 group-data-[collapsible=offcanvas]:left-[calc(var(--sidebar-width)*-1)]" : "right-0 group-data-[collapsible=offcanvas]:right-[calc(var(--sidebar-width)*-1)]", floating|inset ? "p-2 group-data-[collapsible=icon]:w-[calc(var(--sidebar-width-icon)+(--spacing(4))+2px)]" : "group-data-[collapsible=icon]:w-(--sidebar-width-icon) group-data-[side=left]:border-r group-data-[side=right]:border-l", class)` (tsx:231-241). Caller `class:` and `**attrs` (id, data, aria...) land HERE.
- Manifest tokens `floating`, `inset`, `left` are comparison literals, not classes.
- The `<template>` (deviation 1) is a sibling right after the outer `sidebar` div, inert, no `data-slot`. It keeps sibling selectors intact (`peer-data-[variant=inset]` on `Sidebar::Inset` uses `~`).

### Sidebar, mobile (tsx:183-205), mounted by Stimulus only

When the viewport is mobile React renders `Sheet open={openMobile}` INSTEAD of the desktop tree: no `sidebar` / `sidebar-gap` / `sidebar-container` / `sidebar-inner` node exists, and while `openMobile` is false nothing at all is in the DOM for the Sidebar. The template holds:

```ruby
render Components::V2::Sheet.new(open: false) do   # controlled; the chadcn--sidebar controller drives its open value
  render Components::V2::Sheet::Content.new(side: side, class: "w-(--sidebar-width) bg-sidebar p-0 text-sidebar-foreground [&>button]:hidden",
    style: "--sidebar-width: 18rem;", data: { sidebar: "sidebar", slot: "sidebar", mobile: "true" }) do
    render Components::V2::Sheet::Header.new(class: "sr-only") do
      render Components::V2::Sheet::Title.new { "Sidebar" }
      render Components::V2::Sheet::Description.new { "Displays the mobile sidebar." }
    end
    div(class: "flex h-full w-full flex-col", data: { chadcn__sidebar_target: "mobileBody" }) # children are moved here
  end
end
```

Resulting DOM while open (appended to `body` by the Sheet, per `specs/sheet.md`): `div[data-slot=sheet-overlay]`, then `div[role=dialog][data-slot=sidebar][data-sidebar=sidebar][data-mobile=true][data-state=open][tabindex=-1]` with `aria-labelledby` -> `sheet-title`, `aria-describedby` -> `sheet-description`, style `--sidebar-width: 18rem`, classes = `cn(sheet base, sheet side left|right, "w-(--sidebar-width) bg-sidebar p-0 text-sidebar-foreground [&>button]:hidden")`; children in order: `div[data-slot=sheet-header].sr-only` (`h2[data-slot=sheet-title]` "Sidebar", `p[data-slot=sheet-description]` "Displays the mobile sidebar."), `div.flex.h-full.w-full.flex-col` with the Sidebar block, then the Sheet X close (`button`, no data-slot, `display: none` via `[&>button]:hidden`). The caller's `class:`/`**attrs` on `Sidebar` are NOT rendered in mobile mode (tsx:185). Only `side` reaches the Sheet; `variant`/`collapsible` are ignored.

The block is rendered ONCE by the server (inside `sidebar-inner`). The controller moves the block's nodes between `sidebar-inner` (desktop) and the `mobileBody` div (mobile); there is never a second copy (ids, forms and nested controllers stay unique).

### Other parts (all `data-slot` + `data-sidebar` as in the source; `data-slot` first, `data-sidebar` second, then class, then attrs)

| Part | Tag | data-slot / data-sidebar | Other attributes | Classes (`cn(..., class)`) |
|---|---|---|---|---|
| `Sidebar::Trigger` | `button` (Button) | `sidebar-trigger` / `trigger` | `data-variant="ghost"`, `data-size="icon"` (Button, or the caller's values); no `type` | Button `variants(variant: "ghost", size: "icon", class: cn("size-7", class))`. Children: `Icon("panel-left")` (`<svg class="lucide lucide-panel-left" aria-hidden="true" ...>`, Button sizes it via `[&_svg:not([class*='size-'])]:size-4`), then `<span class="sr-only">Toggle Sidebar</span>` |
| `Sidebar::Rail` | `button` (no `type`) | `sidebar-rail` / `rail` | `aria-label="Toggle Sidebar" tabindex="-1" title="Toggle Sidebar"` | `absolute inset-y-0 z-20 hidden w-4 -translate-x-1/2 transition-all ease-linear group-data-[side=left]:-right-4 group-data-[side=right]:left-0 after:absolute after:inset-y-0 after:left-1/2 after:w-[2px] hover:after:bg-sidebar-border sm:flex in-data-[side=left]:cursor-w-resize in-data-[side=right]:cursor-e-resize [[data-side=left][data-state=collapsed]_&]:cursor-e-resize [[data-side=right][data-state=collapsed]_&]:cursor-w-resize group-data-[collapsible=offcanvas]:translate-x-0 group-data-[collapsible=offcanvas]:after:left-full hover:group-data-[collapsible=offcanvas]:bg-sidebar [[data-side=left][data-collapsible=offcanvas]_&]:-right-2 [[data-side=right][data-collapsible=offcanvas]_&]:-left-2` |
| `Sidebar::Inset` | `main` | `sidebar-inset` / none | | `relative flex w-full flex-1 flex-col bg-background md:peer-data-[variant=inset]:m-2 md:peer-data-[variant=inset]:ml-0 md:peer-data-[variant=inset]:rounded-xl md:peer-data-[variant=inset]:shadow-sm md:peer-data-[variant=inset]:peer-data-[state=collapsed]:ml-2` |
| `Sidebar::Input` | `input` (Input) | `sidebar-input` / `input` | Input's `type` rule | Input classes merged with `h-8 w-full bg-background shadow-none` |
| `Sidebar::Header` | `div` | `sidebar-header` / `header` | | `flex flex-col gap-2 p-2` |
| `Sidebar::Footer` | `div` | `sidebar-footer` / `footer` | | `flex flex-col gap-2 p-2` |
| `Sidebar::Separator` | `div` (Separator) | `sidebar-separator` / `separator` | `data-orientation`, `role="none"` (decorative) or `role="separator"` + `aria-orientation` (vertical, non-decorative), per Separator | Separator classes merged with `mx-2 w-auto bg-sidebar-border` |
| `Sidebar::Content` | `div` | `sidebar-content` / `content` | | `flex min-h-0 flex-1 flex-col gap-2 overflow-auto group-data-[collapsible=icon]:overflow-hidden` |
| `Sidebar::Group` | `div` | `sidebar-group` / `group` | | `relative flex w-full min-w-0 flex-col p-2` |
| `Sidebar::GroupLabel` | `div` / child | `sidebar-group-label` / `group-label` | | `flex h-8 shrink-0 items-center rounded-md px-2 text-xs font-medium text-sidebar-foreground/70 ring-sidebar-ring outline-hidden transition-[margin,opacity] duration-200 ease-linear focus-visible:ring-2 [&>svg]:size-4 [&>svg]:shrink-0 group-data-[collapsible=icon]:-mt-8 group-data-[collapsible=icon]:opacity-0` |
| `Sidebar::GroupAction` | `button` / child | `sidebar-group-action` / `group-action` | | `absolute top-3.5 right-3 flex aspect-square w-5 items-center justify-center rounded-md p-0 text-sidebar-foreground ring-sidebar-ring outline-hidden transition-transform hover:bg-sidebar-accent hover:text-sidebar-accent-foreground focus-visible:ring-2 [&>svg]:size-4 [&>svg]:shrink-0 after:absolute after:-inset-2 md:after:hidden group-data-[collapsible=icon]:hidden` |
| `Sidebar::GroupContent` | `div` | `sidebar-group-content` / `group-content` | | `w-full text-sm` |
| `Sidebar::Menu` | `ul` | `sidebar-menu` / `menu` | | `flex w-full min-w-0 flex-col gap-1` |
| `Sidebar::MenuItem` | `li` | `sidebar-menu-item` / `menu-item` | | `group/menu-item relative` |
| `Sidebar::MenuButton` | `button` / child | `sidebar-menu-button` / `menu-button` | `data-size="{size}"`, `data-active="true\|false"` (always rendered, string of the boolean, tsx:518-519); no `type` | `cn(MenuButton.variants(variant:, size:), class)`; base + variant + size tables verbatim from tsx:476-496 (manifest `cva.sidebarMenuButtonVariants`) |
| `Sidebar::MenuAction` | `button` / child | `sidebar-menu-action` / `menu-action` | | `absolute top-1.5 right-1 flex aspect-square w-5 items-center justify-center rounded-md p-0 text-sidebar-foreground ring-sidebar-ring outline-hidden transition-transform peer-hover/menu-button:text-sidebar-accent-foreground hover:bg-sidebar-accent hover:text-sidebar-accent-foreground focus-visible:ring-2 [&>svg]:size-4 [&>svg]:shrink-0 after:absolute after:-inset-2 md:after:hidden peer-data-[size=sm]/menu-button:top-1 peer-data-[size=default]/menu-button:top-1.5 peer-data-[size=lg]/menu-button:top-2.5 group-data-[collapsible=icon]:hidden`, plus when `show_on_hover`: `group-focus-within/menu-item:opacity-100 group-hover/menu-item:opacity-100 peer-data-[active=true]/menu-button:text-sidebar-accent-foreground data-[state=open]:opacity-100 md:opacity-0` |
| `Sidebar::MenuBadge` | `div` | `sidebar-menu-badge` / `menu-badge` | | `pointer-events-none absolute right-1 flex h-5 min-w-5 items-center justify-center rounded-md px-1 text-xs font-medium text-sidebar-foreground tabular-nums select-none peer-hover/menu-button:text-sidebar-accent-foreground peer-data-[active=true]/menu-button:text-sidebar-accent-foreground peer-data-[size=sm]/menu-button:top-1 peer-data-[size=default]/menu-button:top-1.5 peer-data-[size=lg]/menu-button:top-2.5 group-data-[collapsible=icon]:hidden` |
| `Sidebar::MenuSkeleton` | `div` | `sidebar-menu-skeleton` / `menu-skeleton` | | `flex h-8 items-center gap-2 rounded-md px-2`. Children: when `show_icon`, `Components::V2::Skeleton.new(class: "size-4 rounded-md", data: { sidebar: "menu-skeleton-icon" })`; always `Components::V2::Skeleton.new(class: "h-4 max-w-(--skeleton-width) flex-1", data: { sidebar: "menu-skeleton-text" }, style: "--skeleton-width: <w>%;")` with `w = rand(40) + 50` per instance (tsx:610-612 `Math.floor(Math.random() * 40) + 50`, i.e. 50..89). Both Skeletons keep `data-slot="skeleton"`. |
| `Sidebar::MenuSub` | `ul` | `sidebar-menu-sub` / `menu-sub` | | `mx-3.5 flex min-w-0 translate-x-px flex-col gap-1 border-l border-sidebar-border px-2.5 py-0.5 group-data-[collapsible=icon]:hidden` |
| `Sidebar::MenuSubItem` | `li` | `sidebar-menu-sub-item` / `menu-sub-item` | | `group/menu-sub-item relative` |
| `Sidebar::MenuSubButton` | `a` / child | `sidebar-menu-sub-button` / `menu-sub-button` | `data-size="sm\|md"`, `data-active="true\|false"` | `flex h-7 min-w-0 -translate-x-px items-center gap-2 overflow-hidden rounded-md px-2 text-sidebar-foreground ring-sidebar-ring outline-hidden hover:bg-sidebar-accent hover:text-sidebar-accent-foreground focus-visible:ring-2 active:bg-sidebar-accent active:text-sidebar-accent-foreground disabled:pointer-events-none disabled:opacity-50 aria-disabled:pointer-events-none aria-disabled:opacity-50 [&>span:last-child]:truncate [&>svg]:size-4 [&>svg]:shrink-0 [&>svg]:text-sidebar-accent-foreground data-[active=true]:bg-sidebar-accent data-[active=true]:text-sidebar-accent-foreground`, then `text-xs` (sm) or `text-sm` (md), then `group-data-[collapsible=icon]:hidden` |

### MenuButton with `tooltip:` (tsx:525-545)

```ruby
render Components::V2::Tooltip.new do
  render Components::V2::Tooltip::Trigger.new(as_child: <the MenuButton element above>)
  render Components::V2::Tooltip::Content.new(side: "right", align: "center", hidden: <state != "collapsed" || is_mobile>, **tooltip_hash) { tooltip_hash[:children] }
end
```

- The button therefore also carries the Tooltip trigger attributes: `data-state="closed|delayed-open|instant-open"` (tooltip:187) and, while open, `aria-describedby`; child (`sidebar-menu-button`) attributes win the Slot merge, so `data-slot` stays `sidebar-menu-button`. Without `tooltip:` the button has no `data-state`.
- `hidden` reaches the content div (`...contentProps` spread onto `PopperPrimitive.Content`, tooltip:346-350): when `true` React renders `hidden=""` on `div[data-slot=tooltip-content]` (the tooltip still opens: trigger `data-state`, `aria-describedby`, wrapper mounted, content `display: none`); when `false` no attribute. Server value: `hidden` = `state != "collapsed"` (server `is_mobile` is false). The `chadcn--sidebar` controller keeps it current on every desktop state change and mobile switch, on the not-yet-mounted content (inside the tooltip's `<template>`) and on a mounted one; the tooltip content and its template carry `data-chadcn--sidebar-target="tooltip"`-style wiring only (ignored by the runner). A caller `hidden:` in the Hash wins and is then never touched by the controller.

### Server vs Stimulus

Server renders everything above for the initial desktop state (`state` from `open`/`default_open`, `is_mobile` false), which equals React's first render (mobile:6, 18). Stimulus: `connect()` evaluates the media query and, if mobile, switches to the mobile mode immediately; it updates `data-state`/`data-collapsible` on every `[data-slot=sidebar]` desktop target, tooltip `hidden`, and the Sheet open value. Ids: only the mobile Sheet's title/description ids (generated by `Components::V2::Sheet`).

## Behavior

Composes `Components::V2::Sheet` (mobile; primitives `portal`, `presence`, `dismissable_layer`, `focus_scope`, `focus_guards`, `hide_others`, `scroll_lock`, `ids` through `chadcn--sheet`) and `Components::V2::Tooltip` (menu-button tooltips; `positioner`, `presence`, `portal`, `dismissable_layer`, `hover_intent`, `ids` through `chadcn--tooltip`). The `chadcn--sidebar` controller itself uses no Radix primitive: it owns the Provider state, the media query, the cookie and the shortcut.

**State (tsx:69-127).** Desktop `open` (uncontrolled `_open` from `default_open`, or controlled `open`), derived `state = open ? "expanded" : "collapsed"`; mobile `openMobile` (always starts `false`, tsx:70, not controllable); `isMobile`.

**Transitions**

| Trigger | isMobile false | isMobile true |
|---|---|---|
| click `Sidebar::Trigger` (tsx:270-273) or `Enter`/`Space` on it (native button) | `setOpen(!open)` | `setOpenMobile(!openMobile)` |
| click `Sidebar::Rail` (tsx:291) | `setOpen(!open)` | `setOpenMobile(!openMobile)` (a rail inside the open Sheet closes it) |
| `keydown` on `window` with `event.key === "b"` and (`metaKey` or `ctrlKey`) (tsx:97-110) | `preventDefault()`, `setOpen(!open)` | `preventDefault()`, `setOpenMobile(!openMobile)` |
| Sheet `open-change` (Escape, overlay click, any Sheet dismissal; tsx:185 `onOpenChange={setOpenMobile}`) | n/a | `setOpenMobile(detail.open)` |
| `chadcn--sidebar#setOpen` / `#setOpenMobile` / `#toggle` actions | as above | as above |

- `setOpen(value)` (tsx:76-89): compute the new value (toggle uses the CURRENT `open`, which in controlled mode is the prop); controlled -> dispatch `open-change` only (desktop DOM unchanged); uncontrolled -> update the state and the DOM, dispatch `open-change`; in BOTH modes write `document.cookie = "sidebar_state=<true|false>; path=/; max-age=604800"`. `setOpenMobile` never writes the cookie. Note the React quirk that controlled `open` without a handler keeps re-requesting the same value (e.g. `open: false` + toggle always writes `true`); the port matches it because toggle reads the controlled value.
- The shortcut: exact `"b"` only (`Shift` makes the key `"B"`, no toggle); no target filtering, so it fires while typing in `Sidebar::Input` or any field; one listener per Provider on `window` (two Providers both toggle). Native `Ctrl/Cmd+B` default is prevented only when it matches.
- The desktop transition is pure CSS: `data-state`/`data-collapsible` change on the outer `sidebar` div; `transition-[width]` (gap) and `transition-[left,right,width]` (container) `duration-200 ease-linear`, label `transition-[margin,opacity]`. No Presence, no timers, no focus movement: focus stays where it was (e.g. on the trigger).
- `collapsible: "offcanvas"` collapsed: gap width 0, container moved off-screen by `--sidebar-width` (still in the DOM, still tabbable). `"icon"` collapsed: widths become `--sidebar-width-icon` (+ `--spacing(4)` (+2px) for floating/inset), labels fade with `-mt-8 opacity-0`, actions/badges/subs `hidden`, menu buttons `size-8! p-2!` (`lg`: `p-0!`), content `overflow-hidden`; tooltips start showing. `"none"`: no state at all.

**Mobile (`useIsMobile`, mobile:5-19).** `isMobile = window.innerWidth < 768`, evaluated in `connect()` and on `change` of `matchMedia("(max-width: 767px)")` (the handler reads `innerWidth`, not `mql.matches`). Switching to mobile: detach every desktop `sidebar` node of this Provider (remove it from the DOM, keep it in memory) and put the mobile Sheet host in its place, move the block nodes into `mobileBody`; the Sheet is open iff `openMobile`. Switching to desktop: unmount the Sheet completely (as React unmounts it: overlay/content removed from `body`, scroll lock, `pointer-events`, `aria-hidden` and focus guards released, no exit animation since the subtree is gone), move the block back into `sidebar-inner`, re-insert the desktop node. `openMobile` survives switches (open the sheet, resize to desktop and back: it is open again). `collapsible: "none"` sidebars never switch. Inside the open Sheet (`specs/sheet.md`): modal, focus trap with Tab loop, first non-link tabbable gets focus on open (`removeLinks`, fs:99, 266-268; with only `<a>` menu buttons and the `display: none` X close nothing takes focus, so the Sheet content itself is focused and shows the UA outline), Escape and overlay click close (they go through `open-change` -> `setOpenMobile(false)`), close focus goes to the Sheet trigger, and there is none (`context.triggerRef.current?.focus()` with a null ref, dialog:174-177), so focus ends on `body`. Clicks on a `Sidebar::Trigger`/`Sidebar::Rail` inside the portaled Sheet content must still reach this Provider's controller (the content is no longer inside the wrapper element), e.g. by binding the listener on the mounted content or by delegating on `document` and resolving the owning Provider.

**Tooltips.** `TooltipProvider delayDuration={0}`: hover opens after `setTimeout(0)` as `delayed-open`; keyboard focus opens `instant-open`; skip delay 300ms; side `right`, align `center`, side offset 0 (Tooltip defaults, see `specs/tooltip.md`). Visible only when `state === "collapsed"` and not mobile (`hidden` above), unless the caller overrides `hidden`. Collapsing while a tooltip is open (Ctrl+B) removes `hidden` at once, so the open tooltip becomes visible.

**Keyboard summary.** `Ctrl+B` / `Cmd+B` anywhere: toggle (desktop or mobile). `Enter`/`Space` on Trigger: toggle. Rail is not in the tab order (`tabindex="-1"`). Menu buttons, actions, sub buttons, group label/action children: native focus only (no roving focus, no arrow keys). Escape: closes an open tooltip or the mobile Sheet (top layer only).

**Cleanup (radix-stimulus R10).** `disconnect()` removes the `window` keydown and `matchMedia` listeners, unmounts an open mobile Sheet, restores the desktop node and the block if it was in mobile mode (so a Turbo cache snapshot holds the server structure).

Not observable by the runner (controller unit tests instead): the cookie string, `open-change` / `open-mobile-change` details, two Providers on one page.

<!-- spec_helpers:begin -->
## DX helpers (derived from the oracle, do not edit)

`Chadcn::Sidebar` MUST `yield self` from `view_template`; `Chadcn::Base` generates one helper per nested part (`const_added`), each exactly `render Sidebar::<Part>.new(**attrs), &block`. The helpers are sugar: the nested classes stay the canonical API (scenarios, tests and the parity harness use them), and fully qualified calls (`render Chadcn::Sidebar::Content.new`) stay valid.

| helper | part class | React export |
|---|---|---|
| `sidebar.content` | `Sidebar::Content` | `SidebarContent` |
| `sidebar.footer` | `Sidebar::Footer` | `SidebarFooter` |
| `sidebar.group` | `Sidebar::Group` | `SidebarGroup` |
| `sidebar.group_action` | `Sidebar::GroupAction` | `SidebarGroupAction` |
| `sidebar.group_content` | `Sidebar::GroupContent` | `SidebarGroupContent` |
| `sidebar.group_label` | `Sidebar::GroupLabel` | `SidebarGroupLabel` |
| `sidebar.header` | `Sidebar::Header` | `SidebarHeader` |
| `sidebar.input` | `Sidebar::Input` | `SidebarInput` |
| `sidebar.inset` | `Sidebar::Inset` | `SidebarInset` |
| `sidebar.menu` | `Sidebar::Menu` | `SidebarMenu` |
| `sidebar.menu_action` | `Sidebar::MenuAction` | `SidebarMenuAction` |
| `sidebar.menu_badge` | `Sidebar::MenuBadge` | `SidebarMenuBadge` |
| `sidebar.menu_button` | `Sidebar::MenuButton` | `SidebarMenuButton` |
| `sidebar.menu_item` | `Sidebar::MenuItem` | `SidebarMenuItem` |
| `sidebar.menu_skeleton` | `Sidebar::MenuSkeleton` | `SidebarMenuSkeleton` |
| `sidebar.menu_sub` | `Sidebar::MenuSub` | `SidebarMenuSub` |
| `sidebar.menu_sub_button` | `Sidebar::MenuSubButton` | `SidebarMenuSubButton` |
| `sidebar.menu_sub_item` | `Sidebar::MenuSubItem` | `SidebarMenuSubItem` |
| `sidebar.provider` | `Sidebar::Provider` | `SidebarProvider` |
| `sidebar.rail` | `Sidebar::Rail` | `SidebarRail` |
| `sidebar.separator` | `Sidebar::Separator` | `SidebarSeparator` |
| `sidebar.trigger` | `Sidebar::Trigger` | `SidebarTrigger` |

Names that shadow a Phlex HTML element inside `Sidebar`'s OWN `view_template` (use `tag(:footer)` there, never the bare method): `footer`, `header`, `input`, `menu`.

Acceptance (unit test): every row exists as a public method on the root instance and renders the same HTML as the explicit class call; no helper is defined by hand.
<!-- spec_helpers:end -->

## Dependencies

- `Components::V2::Button` (Trigger), `Components::V2::Input` (Sidebar::Input), `Components::V2::Separator` (Sidebar::Separator), `Components::V2::Skeleton` (MenuSkeleton), `Components::V2::Sheet` + `Sheet::Content`, `Sheet::Header`, `Sheet::Title`, `Sheet::Description` (mobile), `Components::V2::Tooltip`, `Tooltip::Provider`, `Tooltip::Trigger`, `Tooltip::Content` (Provider and MenuButton `tooltip:`), `Components::V2::Icon` (`panel-left` in Trigger). All planned in `dev/port/specs/`.
- `Components::V2::Base`: `cn`, `merge_attrs`, `render_as_child`, Phlex render context for the Provider state.
- Controllers: `chadcn--sidebar` (new), driving `chadcn--sheet` (controlled `open` value + `open-change` event) and adjusting `chadcn--tooltip` content `hidden`.
- Scenario trees also use `Button` (sidebar-controlled example) and `Separator` (inset header), both registry dependencies.

## Deviations

Recorded in `dev/port/deviations/sidebar.json`:

1. **Mobile Sheet markup in a `<template>` and node moving.** React decides desktop vs mobile on the client and renders entirely different trees (tsx:183-206). The server cannot know the viewport, so `Sidebar` (non-`none`) emits the desktop tree (= React's first render) plus an inert `<template>` sibling holding the controlled `Components::V2::Sheet` (whose own host is the `display: contents` element of `deviations/sheet.json`); on mobile the controller detaches the desktop node, mounts the Sheet host in its place and moves the block nodes. Neither the template nor the Sheet host carries a `data-slot`, classes or layout, so G2 node lists, boxes and a11y equal the oracle.
2. **`SidebarMenuSkeleton` width is random in the oracle** (`Math.random()`, tsx:610-612), so even two React runs differ in the BOX of the text `skeleton` node; the port draws from the same distribution (`rand(40) + 50` percent). Scenarios that need determinism set `style: { width: "60px" }` with `showIcon`, which makes `flex-1` (20px) narrower than any `max-w` (>= 22px); `menu-skeleton__text-only` and `example__sidebar-rsc` keep the random width and their `menu-skeleton-text` BOX width differences are ORACLE_NOISE.
3. **Event API.** `onOpenChange` maps to the always-dispatched `chadcn--sidebar:open-change`; React's corner case "`onOpenChange` given without `open`" (tsx:79-83: internal state never updates, the sidebar is stuck) has no Ruby equivalent because the server cannot know whether a listener exists, so an uncontrolled Provider always updates. `SidebarRail`'s `onClick={toggleSidebar}` is replaced by a caller `onClick` in React (props spread after, tsx:291-302); in the port caller `data-action` descriptors are added, never replacing the toggle. `open-mobile-change` is an extra informational event (React exposes `openMobile` only through `useSidebar`).

No class tokens are added or removed (`allow_tokens` / `allow_missing_tokens` empty).
