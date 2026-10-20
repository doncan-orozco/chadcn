---
name: phlex-shadcn
description: "Use when writing Phlex views with the phlex-shadcn gem (shadcn/ui components for Phlex): component names, constructor keywords, compound parts, Stimulus behavior and theming."
---

# phlex-shadcn

54 shadcn/ui components as Phlex classes under `Phlex::Shadcn`. The exact keywords, variants, parts, controllers and events of every component are in [llms-full.txt](../../llms-full.txt) (generated, always current): read the section of the component before using it.

## Rules

1. Render with `render Phlex::Shadcn::Button.new(variant: "outline") { "Save" }`. Unknown variants or sizes raise `ArgumentError`.
2. Compound components nest parts (`Phlex::Shadcn::Dialog::Content`). The root also yields itself with one helper per part (`dialog.trigger { "Open" }`); both forms render the same markup.
3. Extra keywords become HTML attributes. `class:` is merged with `tailwind_merge` (yours wins), `data:` and `aria:` are deep-merged. Do not copy shadcn Tailwind classes into your views: they are already applied.
4. `as_child:` renders the part's props onto another tag or component instead of its default element.
5. Behavior comes from Stimulus controllers named `shadcn--<component>`. Events are dispatched as `shadcn--<component>:<event>`; values are set with `data-shadcn--<component>-<value>-value`.
6. Colors come from shadcn-format CSS variables (`--primary`, `--background`, ...): change the theme file, not the components.

## Components

`Accordion`, `Alert`, `AlertDialog`, `AspectRatio`, `Attachment`, `Avatar`, `Badge`, `Breadcrumb`, `Bubble`, `Button`, `ButtonGroup`, `Calendar`, `Card`, `Checkbox`, `Collapsible`, `Combobox`, `Command`, `ContextMenu`, `Dialog`, `Direction`, `DropdownMenu`, `Empty`, `Field`, `HoverCard`, `Input`, `InputGroup`, `Item`, `Kbd`, `Label`, `Marker`, `Menubar`, `Message`, `NativeSelect`, `NavigationMenu`, `Pagination`, `Popover`, `Progress`, `RadioGroup`, `ScrollArea`, `Select`, `Separator`, `Sheet`, `Sidebar`, `Skeleton`, `Slider`, `Sonner`, `Spinner`, `Switch`, `Table`, `Tabs`, `Textarea`, `Toggle`, `ToggleGroup`, `Tooltip`.

## Stimulus controllers

`shadcn--accordion`, `shadcn--alert-dialog`, `shadcn--avatar`, `shadcn--calendar`, `shadcn--checkbox`, `shadcn--collapsible`, `shadcn--combobox`, `shadcn--command`, `shadcn--context-menu`, `shadcn--dialog`, `shadcn--dropdown-menu`, `shadcn--hover-card`, `shadcn--input-group`, `shadcn--label`, `shadcn--menubar`, `shadcn--navigation-menu`, `shadcn--popover`, `shadcn--radio-group`, `shadcn--scroll-area`, `shadcn--select`, `shadcn--sheet`, `shadcn--sidebar`, `shadcn--slider`, `shadcn--sonner`, `shadcn--switch`, `shadcn--tabs`, `shadcn--theme`, `shadcn--toggle`, `shadcn--toggle-group`, `shadcn--tooltip`.
