<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/doncan-orozco/papyro/main/gems/chadcn/dev/brand/wordmark-dark.svg">
  <img src="https://raw.githubusercontent.com/doncan-orozco/papyro/main/gems/chadcn/dev/brand/wordmark-light.svg" alt="" width="352" height="96">
</picture>

# chadcn docs

[shadcn/ui](https://ui.shadcn.com) for [Phlex](https://www.phlex.fun): the same component API, the same Tailwind class strings and
the same behavior as the React originals, as Phlex views with Stimulus controllers. Installation, setup, theming and ejecting are
in the [README](../README.md); these pages are the per-family reference.

## Guides

- [API conventions](api-conventions.md): class per React export, keyword arguments, `as_child:`, yielded-root helpers, events.
- [Compatibility](compatibility.md): supported Ruby, Phlex, Rails, Tailwind and Stimulus versions, and the Phlex 3 plan.
- [Form controls](form-controls.md): buttons, inputs, checkbox, switch, radio group, toggle, slider, calendar, `Field`.
- [Display components](display.md): alert, avatar, badge, card, empty, table, toaster and the other static blocks.
- [Overlays](overlays.md): dialog, alert dialog, sheet, popover, tooltip, hover card.
- [Menus, select, command and combobox](menus-and-select.md): dropdown menu, context menu, menubar, select, command, combobox.
- [Disclosure and navigation](disclosure-and-navigation.md): accordion, collapsible, tabs, breadcrumb, pagination, navigation
  menu, sidebar, scroll area.

For AI assistants: [llms.txt](../llms.txt), [llms-full.txt](../llms-full.txt) and the agent skill
[skills/chadcn/SKILL.md](../skills/chadcn/SKILL.md) are generated from the same source as these pages.

## Credits

chadcn is an independent, community-maintained port of [shadcn/ui](https://ui.shadcn.com) to Phlex. It is not affiliated
with, endorsed by or sponsored by shadcn or the shadcn/ui project. Component structure, class strings and behavior derive
from shadcn/ui (MIT License, Copyright (c) 2023 shadcn); accessibility behavior follows Radix UI (MIT) and icons are
Lucide (ISC). Every third-party notice is in [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md). chadcn itself is MIT licensed.
