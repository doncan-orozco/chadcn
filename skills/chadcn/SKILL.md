---
name: chadcn
description: "Use when writing Phlex views with the chadcn gem (shadcn/ui components for Phlex): component names, constructor keywords, compound parts, Stimulus behavior and theming."
---

# chadcn

chadcn is a Ruby gem (RubyGems only). Not affiliated with shadcn. Built on shadcn/ui (MIT). Setup: [README](../../README.md).

60 shadcn/ui components as Phlex classes under `Chadcn`. The exact keywords, variants, parts, controllers and events of every component are in [llms-full.txt](../../llms-full.txt) (generated, always current): read the section of the component before using it.

## Rules

1. Render with `render Chadcn::Button.new(variant: "outline") { "Save" }`. Unknown variants or sizes raise `ArgumentError`.
2. Compound components nest parts (`Chadcn::Dialog::Content`). The root also yields itself with one helper per part (`dialog.trigger { "Open" }`); both forms render the same markup.
3. Extra keywords become HTML attributes. `class:` is merged with `tailwind_merge` (yours wins), `data:` and `aria:` are deep-merged. Do not copy shadcn Tailwind classes into your views: they are already applied.
4. `as_child:` renders the part's props onto another tag or component instead of its default element.
5. Behavior comes from Stimulus controllers named `chadcn--<component>`. Events are dispatched as `chadcn--<component>:<event>`; values are set with `data-chadcn--<component>-<value>-value`.
6. Colors come from shadcn-format CSS variables (`--primary`, `--background`, ...): change the theme file, not the components.

## Components

`Accordion`, `Alert`, `AlertDialog`, `AspectRatio`, `Attachment`, `Avatar`, `Badge`, `Breadcrumb`, `Bubble`, `Button`, `ButtonGroup`, `Calendar`, `Card`, `Carousel`, `Chart`, `Checkbox`, `Collapsible`, `Combobox`, `Command`, `ContextMenu`, `Dialog`, `Direction`, `Drawer`, `DropdownMenu`, `Empty`, `Field`, `Form`, `HoverCard`, `Input`, `InputGroup`, `InputOtp`, `Item`, `Kbd`, `Label`, `Marker`, `Menubar`, `Message`, `NativeSelect`, `NavigationMenu`, `Pagination`, `Popover`, `Progress`, `RadioGroup`, `Resizable`, `ScrollArea`, `Select`, `Separator`, `Sheet`, `Sidebar`, `Skeleton`, `Slider`, `Sonner`, `Spinner`, `Switch`, `Table`, `Tabs`, `Textarea`, `Toggle`, `ToggleGroup`, `Tooltip`.

## Stimulus controllers

`chadcn--accordion`, `chadcn--alert-dialog`, `chadcn--avatar`, `chadcn--calendar`, `chadcn--carousel`, `chadcn--checkbox`, `chadcn--collapsible`, `chadcn--combobox`, `chadcn--command`, `chadcn--context-menu`, `chadcn--dialog`, `chadcn--drawer`, `chadcn--dropdown-menu`, `chadcn--form`, `chadcn--hover-card`, `chadcn--input-group`, `chadcn--input-otp`, `chadcn--label`, `chadcn--menubar`, `chadcn--navigation-menu`, `chadcn--popover`, `chadcn--radio-group`, `chadcn--resizable`, `chadcn--scroll-area`, `chadcn--select`, `chadcn--sheet`, `chadcn--sidebar`, `chadcn--slider`, `chadcn--sonner`, `chadcn--switch`, `chadcn--tabs`, `chadcn--theme`, `chadcn--toggle`, `chadcn--toggle-group`, `chadcn--tooltip`.
