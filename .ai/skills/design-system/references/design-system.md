# Design System Examples (shadcn/ui → Phlex)

Complete examples converting shadcn/ui components to Phlex.

## Button Component

### shadcn/ui Source (React)

```tsx
const buttonVariants = cva(
  "inline-flex items-center justify-center rounded-md text-sm font-medium ring-offset-white transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-slate-950 focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-50",
  {
    variants: {
      variant: {
        default: "bg-slate-900 text-slate-50 hover:bg-slate-900/90",
        destructive: "bg-red-500 text-slate-50 hover:bg-red-500/90",
        outline: "border border-slate-200 bg-white hover:bg-slate-100",
        secondary: "bg-slate-100 text-slate-900 hover:bg-slate-100/80",
        ghost: "hover:bg-slate-100 hover:text-slate-900",
        link: "text-slate-900 underline-offset-4 hover:underline",
      },
      size: {
        default: "h-10 px-4 py-2",
        sm: "h-9 rounded-md px-3",
        lg: "h-11 rounded-md px-8",
        icon: "h-10 w-10",
      },
    },
  }
)
```

### Phlex Translation

```ruby
# app/components/ui/button.rb
# Uses shadcn/ui Radix exact classes with semantic tokens (Tailwind v4)
# Updated: 2026-02-16 for pixel-perfect shadcn Radix UI compatibility
module Components
  module Ui
    class Button < Components::Base
      def initialize(variant: :default, size: :default, **attrs)
        @variant = variant
        @size = size
        @attrs = attrs
      end

      def view_template(&block)
        button(class: classes, **@attrs, &block)
      end

      private

      def classes
        [base_classes, variant_classes[@variant], size_classes[@size]].compact.join(" ")
      end

      def base_classes
        [
          # Layout
          "inline-flex items-center justify-center whitespace-nowrap",
          # SVG handling
          "[&_svg:not([class*='size-'])]:size-4",
          "[&_svg]:pointer-events-none",
          "shrink-0 [&_svg]:shrink-0",
          # Focus and interaction states
          "transition-all",
          "focus-visible:ring-3",
          "aria-invalid:ring-3 aria-invalid:ring-destructive/20 dark:aria-invalid:ring-destructive/40",
          "aria-invalid:border-destructive dark:aria-invalid:border-destructive/50",
          # Disabled state
          "disabled:pointer-events-none disabled:opacity-50",
          # Styling
          "rounded-lg border border-transparent bg-clip-padding text-sm font-medium outline-none group/button select-none"
        ].join(" ")
      end

      def variant_classes
        {
          default: "bg-primary text-primary-foreground hover:bg-primary/90 focus-visible:ring-primary/20 dark:focus-visible:ring-primary/40",
          destructive: "bg-destructive/10 hover:bg-destructive/20 dark:bg-destructive/20 dark:hover:bg-destructive/30 text-destructive focus-visible:ring-destructive/20 dark:focus-visible:ring-destructive/40 focus-visible:border-destructive/40",
          outline: "border-border bg-background text-foreground hover:bg-muted hover:text-foreground dark:border-input dark:hover:bg-muted focus-visible:ring-ring/20",
          secondary: "bg-secondary text-secondary-foreground hover:bg-secondary/80 dark:bg-secondary dark:hover:bg-secondary/80 focus-visible:ring-secondary/20",
          ghost: "text-foreground hover:bg-muted dark:hover:bg-muted focus-visible:ring-muted/20",
          link: "text-foreground underline-offset-4 hover:underline dark:text-foreground"
        }
      end

      def size_classes
        {
          default: "h-8 gap-1.5 px-2.5 has-data-[icon=inline-end]:pr-2 has-data-[icon=inline-start]:pl-2",
          xs: "h-6 gap-1 px-2 text-xs has-data-[icon=inline-end]:pr-1.5 has-data-[icon=inline-start]:pl-1.5",
          sm: "h-8 gap-1.5 px-3 has-data-[icon=inline-end]:pr-2 has-data-[icon=inline-start]:pl-2",
          lg: "h-10 gap-2 px-4 has-data-[icon=inline-end]:pr-3 has-data-[icon=inline-start]:pl-3",
          icon: "h-8 w-8",
          "icon-xs": "h-6 w-6",
          "icon-sm": "h-8 w-8",
          "icon-lg": "h-10 w-10"
        }
      end
    end
  end
end
```

**Key Implementation Notes:**
- Uses **semantic color tokens** with Tailwind v4 CSS variables (`bg-primary`, `text-destructive`, etc.)
- **Border radius**: `rounded-lg` (8px) - shadcn Radix standard
- **Height**: `h-8` (32px) for default size - more compact than Base UI version
- **Focus ring**: `ring-3` (thicker ring) with opacity modifiers for subtlety
- **Transition**: `transition-all` for smooth animations on all properties
- **Destructive variant**: Uses subtle `bg-destructive/10` background (10% opacity) with solid text color
- **SVG handling**: Automatic icon sizing and pointer-events management
- **ARIA support**: Built-in invalid state styling with rings and borders
- **Icon spacing**: `has-data-[icon=inline-end]` attributes for proper padding with icons
- Passes all HTML attributes via `**attrs` for Stimulus/data attributes support

### Usage

```ruby
# In a view or component
render Components::Ui::Button.new(variant: :default, size: :default) { "Click me" }
render Components::Ui::Button.new(variant: :destructive) { "Delete" }
render Components::Ui::Button.new(variant: :outline, size: :sm) { "Cancel" }

# With Stimulus
render Components::Ui::Button.new(
  variant: :default,
  data: { action: "click->game--player#attack" }
) { "Attack" }
```

## Card Component

### shadcn/ui Source

```tsx
const Card = ({ className, ...props }) => (
  <div className={cn("rounded-lg border bg-card text-card-foreground shadow-sm", className)} {...props} />
)

const CardHeader = ({ className, ...props }) => (
  <div className={cn("flex flex-col space-y-1.5 p-6", className)} {...props} />
)

const CardTitle = ({ className, ...props }) => (
  <h3 className={cn("font-semibold leading-none tracking-tight", className)} {...props} />
)

const CardDescription = ({ className, ...props }) => (
  <p className={cn("text-sm text-muted-foreground", className)} {...props} />
)

const CardContent = ({ className, ...props }) => (
  <div className={cn("p-6 pt-0", className)} {...props} />
)

const CardFooter = ({ className, ...props }) => (
  <div className={cn("flex items-center p-6 pt-0", className)} {...props} />
)
```

### Phlex Translation

```ruby
# app/components/ui/card.rb
# Uses shadcn/ui Radix semantic tokens (Tailwind v4)
# Updated: 2026-02-16 for pixel-perfect shadcn Radix UI compatibility
module Components
  module Ui
    # Main Card container
    class Card < Components::Base
      def initialize(**attrs)
        @attrs = attrs
      end

      def view_template(&block)
        div(class: classes, **@attrs, &block)
      end

      private

      def classes
        "rounded-lg border border-border bg-card text-card-foreground shadow-sm"
      end
    end

    # Card header with title and description
    class CardHeader < Components::Base
      def initialize(**attrs)
        @attrs = attrs
      end

      def view_template(&block)
        div(class: classes, **@attrs, &block)
      end

      private

      def classes
        "flex flex-col space-y-1.5 p-6"
      end
    end

    # Card title (h3 by default, customizable)
    class CardTitle < Components::Base
      def initialize(as: :h3, **attrs)
        @as = as
        @attrs = attrs
      end

      def view_template(&block)
        public_send(@as, class: classes, **@attrs, &block)
      end

      private

      def classes
        "font-semibold leading-none tracking-tight"
      end
    end

    # Card description text
    class CardDescription < Components::Base
      def initialize(as: :p, **attrs)
        @as = as
        @attrs = attrs
      end

      def view_template(&block)
        public_send(@as, class: classes, **@attrs, &block)
      end

      private

      def classes
        "text-sm text-muted-foreground"
      end
    end

    # Card main content area
    class CardContent < Components::Base
      def initialize(**attrs)
        @attrs = attrs
      end

      def view_template(&block)
        div(class: classes, **@attrs, &block)
      end

      private

      def classes
        "p-6 pt-0"
      end
    end

    # Card footer for actions
    class CardFooter < Components::Base
      def initialize(**attrs)
        @attrs = attrs
      end

      def view_template(&block)
        div(class: classes, **@attrs, &block)
      end

      private

      def classes
        "flex items-center p-6 pt-0"
      end
    end
  end
end
```

**Key Implementation Notes:**
- Uses **semantic color tokens**: `bg-card`, `text-card-foreground`, `text-muted-foreground`, `border-border`
- **Border radius**: `rounded-lg` (8px) - shadcn Radix standard
- **Shadow**: `shadow-sm` for subtle elevation
- **Spacing**: Consistent padding of `p-6` with `pt-0` for content/footer to avoid double-spacing
- **CardTitle/CardDescription**: Customizable HTML element via `as:` parameter (defaults to h3/p)
- All components inherit from `Components::Base` NOT `Phlex::HTML`
- Pass all attributes via `**attrs` for Stimulus/data attributes support
- Simple classes (no variants) - cards are typically styled by composition

### Usage

```ruby
# Basic card
render Components::Ui::Card.new do
  render Components::Ui::CardHeader.new do
    render Components::Ui::CardTitle.new { "Card Title" }
    render Components::Ui::CardDescription.new { "Card description text" }
  end
  
  render Components::Ui::CardContent.new do
    p { "Main card content goes here" }
  end
end

# Card with footer
render Components::Ui::Card.new do
  render Components::Ui::CardHeader.new do
    render Components::Ui::CardTitle.new { "Settings" }
  end
  
  render Components::Ui::CardContent.new do
    p { "Configure your preferences" }
  end
  
  render Components::Ui::CardFooter.new do
    render Components::Ui::Button.new(variant: :outline) { "Cancel" }
    render Components::Ui::Button.new(variant: :default) { "Save" }
  end
end

# Custom heading level
render Components::Ui::Card.new do
  render Components::Ui::CardHeader.new do
    render Components::Ui::CardTitle.new(as: :h2) { "Game Stats" }
  end
  
  render Components::Ui::CardContent.new do
    p { "Level: 42" }
    p { "HP: 1000" }
  end
end
```

## Input Component

### shadcn/ui Source

```tsx
const Input = ({ className, type, ...props }) => {
  return (
    <input
      type={type}
      className={cn(
        "flex h-10 w-full rounded-md border border-slate-200 bg-white px-3 py-2 text-sm ring-offset-white file:border-0 file:bg-transparent file:text-sm file:font-medium placeholder:text-slate-500 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-slate-950 focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50",
        className
      )}
      {...props}
    />
  )
}
```

### Phlex Translation

```ruby
# app/components/ui/input.rb
module Components
  module Ui
    class Input < Phlex::HTML
      def initialize(type: :text, disabled: false, **attrs)
        @type = type
        @disabled = disabled
        @attrs = attrs
      end

      def view_template
        input(
          type: @type,
          class: classes,
          disabled: @disabled,
          **@attrs
        )
      end

      private

      def classes
        "flex h-10 w-full rounded-md border border-slate-200 bg-white px-3 py-2 text-sm ring-offset-white file:border-0 file:bg-transparent file:text-sm file:font-medium placeholder:text-slate-500 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-slate-950 focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50"
      end
    end
  end
end
```

### Usage

```ruby
render Components::Ui::Input.new(
  type: :text,
  placeholder: "Enter player name",
  name: "player[name]"
)

# With Stimulus
render Components::Ui::Input.new(
  type: :text,
  data: {
    controller: "game--player",
    action: "input->game--player#updateName"
  }
)
```

## Alert Component

### shadcn/ui Source (summary)

```tsx
const alertVariants = cva(
  "relative w-full rounded-lg border p-4",
  { variants: { variant: { default: "bg-background", destructive: "border-red-500/50 text-red-600" } } }
)
```

### Phlex Translation

```ruby
# app/components/ui/alert.rb
module Components
  module Ui
    class Alert < Phlex::HTML
      def initialize(variant: :default, **attrs)
        @variant = variant
        @attrs = attrs
      end

      def view_template(&block)
        div(class: classes, role: "alert", **@attrs, &block)
      end

      private

      def classes
        [base_classes, variant_classes[@variant]].compact.join(" ")
      end

      def base_classes
        "relative w-full rounded-lg border p-4"
      end

      def variant_classes
        {
          default: "bg-background text-foreground",
          destructive: "border-red-500/50 text-red-600 dark:border-red-500/50"
        }
      end
    end

    class AlertTitle < Phlex::HTML
      def view_template(&block)
        h5(class: "mb-1 font-medium leading-none tracking-tight", &block)
      end
    end

    class AlertDescription < Phlex::HTML
      def view_template(&block)
        div(class: "text-sm text-muted-foreground", &block)
      end
    end
  end
end
```

### Usage

```ruby
render Components::Ui::Alert.new do
  render Components::Ui::AlertTitle.new { "Heads up!" }
  render Components::Ui::AlertDescription.new { "Your session will expire soon." }
end

render Components::Ui::Alert.new(variant: :destructive) do
  render Components::Ui::AlertTitle.new { "Error" }
  render Components::Ui::AlertDescription.new { "Payment failed. Try again." }
end
```

## Dropdown Component

### shadcn/ui Source (summary)

```tsx
<DropdownMenu>
  <DropdownMenuTrigger>Open</DropdownMenuTrigger>
  <DropdownMenuContent>
    <DropdownMenuItem>Profile</DropdownMenuItem>
    <DropdownMenuSeparator />
    <DropdownMenuItem>Log out</DropdownMenuItem>
  </DropdownMenuContent>
</DropdownMenu>
```

### Phlex Translation

```ruby
# app/components/ui/dropdown.rb
module Components
  module Ui
    class Dropdown < Phlex::HTML
      def initialize(**attrs)
        @attrs = attrs
      end

      def view_template(&block)
        div(class: "relative inline-block text-left", **@attrs, &block)
      end
    end

    class DropdownTrigger < Phlex::HTML
      def initialize(**attrs)
        @attrs = attrs
      end

      def view_template(&block)
        button(
          type: :button,
          class: "inline-flex items-center",
          **@attrs,
          &block
        )
      end
    end

    class DropdownContent < Phlex::HTML
      def initialize(**attrs)
        @attrs = attrs
      end

      def view_template(&block)
        div(
          class: "absolute right-0 z-10 mt-2 w-56 rounded-md border bg-background shadow-md",
          **@attrs,
          &block
        )
      end
    end

    class DropdownItem < Phlex::HTML
      def initialize(**attrs)
        @attrs = attrs
      end

      def view_template(&block)
        div(
          class: "flex cursor-pointer items-center px-3 py-2 text-sm hover:bg-muted",
          **@attrs,
          &block
        )
      end
    end

    class DropdownSeparator < Phlex::HTML
      def view_template
        div(class: "my-1 h-px bg-border")
      end
    end
  end
end
```

### Usage (with Stimulus)

```ruby
render Components::Ui::Dropdown.new(data: { controller: "ui--dropdown" }) do
  render Components::Ui::DropdownTrigger.new(
    data: { action: "click->ui--dropdown#toggle" }
  ) { "Options" }

  render Components::Ui::DropdownContent.new(
    data: { ui__dropdown_target: "content" },
    class: "hidden"
  ) do
    render Components::Ui::DropdownItem.new { "Profile" }
    render Components::Ui::DropdownSeparator.new
    render Components::Ui::DropdownItem.new { "Log out" }
  end
end
```

## Badge Component

### shadcn/ui Source

```tsx
const badgeVariants = cva(
  "inline-flex items-center rounded-full border px-2.5 py-0.5 text-xs font-semibold transition-colors focus:outline-none focus:ring-2 focus:ring-slate-950 focus:ring-offset-2",
  {
    variants: {
      variant: {
        default: "border-transparent bg-slate-900 text-slate-50 hover:bg-slate-900/80",
        secondary: "border-transparent bg-slate-100 text-slate-900 hover:bg-slate-100/80",
        destructive: "border-transparent bg-red-500 text-slate-50 hover:bg-red-500/80",
        outline: "text-slate-950",
      },
    },
  }
)
```

### Phlex Translation

```ruby
# app/components/ui/badge.rb
module Components
  module Ui
    class Badge < Phlex::HTML
      def initialize(variant: :default, **attrs)
        @variant = variant
        @attrs = attrs
      end

      def view_template(&block)
        div(class: classes, **@attrs, &block)
      end

      private

      def classes
        [base_classes, variant_classes[@variant]].compact.join(" ")
      end

      def base_classes
        "inline-flex items-center rounded-full border px-2.5 py-0.5 text-xs font-semibold transition-colors focus:outline-none focus:ring-2 focus:ring-slate-950 focus:ring-offset-2"
      end

      def variant_classes
        {
          default: "border-transparent bg-slate-900 text-slate-50 hover:bg-slate-900/80",
          secondary: "border-transparent bg-slate-100 text-slate-900 hover:bg-slate-100/80",
          destructive: "border-transparent bg-red-500 text-slate-50 hover:bg-red-500/80",
          outline: "text-slate-950"
        }
      end
    end
  end
end
```

### Usage

```ruby
render Components::Ui::Badge.new(variant: :default) { "Active" }
render Components::Ui::Badge.new(variant: :destructive) { "Critical" }
render Components::Ui::Badge.new(variant: :outline) { "Level 42" }
```

## Avatar Component

### shadcn/ui Source

```tsx
const Avatar = ({ className, ...props }) => (
  <div className={cn("relative flex h-10 w-10 shrink-0 overflow-hidden rounded-full", className)} {...props} />
)

const AvatarImage = ({ className, ...props }) => (
  <img className={cn("aspect-square h-full w-full", className)} {...props} />
)

const AvatarFallback = ({ className, ...props }) => (
  <div className={cn("flex h-full w-full items-center justify-center rounded-full bg-slate-100", className)} {...props} />
)
```

### Phlex Translation

```ruby
# app/components/ui/avatar.rb
module Components
  module Ui
    class Avatar < Phlex::HTML
      def initialize(src: nil, alt: "", fallback: nil, size: :default, **attrs)
        @src = src
        @alt = alt
        @fallback = fallback
        @size = size
        @attrs = attrs
      end

      def view_template
        div(class: container_classes, **@attrs) do
          if @src
            img(src: @src, alt: @alt, class: "aspect-square h-full w-full object-cover")
          else
            div(class: "flex h-full w-full items-center justify-center rounded-full bg-slate-100 text-slate-600 font-semibold") do
              plain @fallback || @alt[0]&.upcase || "?"
            end
          end
        end
      end

      private

      def container_classes
        [
          "relative flex shrink-0 overflow-hidden rounded-full",
          size_classes[@size]
        ].compact.join(" ")
      end

      def size_classes
        {
          sm: "h-8 w-8",
          default: "h-10 w-10",
          lg: "h-16 w-16",
          xl: "h-24 w-24"
        }
      end
    end
  end
end
```

### Usage

```ruby
render Components::Ui::Avatar.new(
  src: player.avatar_url,
  alt: player.name,
  size: :default
)

render Components::Ui::Avatar.new(
  fallback: "JD",
  size: :lg
)
```

## Conversion Checklist

When converting shadcn Radix UI component to Phlex:

1. ✅ Extract all variants from `cva()` definition
2. ✅ **Use semantic color tokens** with opacity modifiers (e.g., `bg-destructive/10` not `bg-red-500`)
3. ✅ Map each variant to Ruby hash preserving exact class names
4. ✅ Add `size` parameter if multiple sizes exist
5. ✅ **Border-radius**: Use `rounded-lg` (8px) for buttons - Radix UI standard
6. ✅ **Height**: Use `h-8` (32px) for default button size - more compact than Base UI
7. ✅ **Transitions**: Use `transition-all` for smooth animations on all properties
8. ✅ **Focus rings**: Use `ring-3` (thicker) with opacity modifiers (`ring-primary/20`)
9. ✅ **SVG handling**: Include `[&_svg:not([class*='size-'])]:size-4` and pointer-events classes
10. ✅ **ARIA states**: Include `aria-invalid` styling for form validation feedback
11. ✅ **Icon spacing**: Add `has-data-[icon=inline-end]` classes for proper padding adjustments
12. ✅ Always include `**attrs` for Stimulus/data attributes
13. ✅ Use `&block` for component children/content
14. ✅ Keep class composition logic in private methods
15. ✅ Include helper classes: `bg-clip-padding`, `outline-none`, `group/button`, `select-none`

**Color Philosophy:** Papyro uses shadcn's semantic color tokens (`--color-primary`, `--color-destructive`, etc.) defined in Tailwind v4 CSS variables. This enables theming while maintaining shadcn's visual design with opacity modifiers for subtle backgrounds.

---

## Table Component

### Component Anatomy

```
div wrapper      ← class="relative w-full overflow-auto"
  Table          ← <table> with w-full text-sm
    TableHeader  ← <thead>
      TableRow   ← <tr> with border-bottom hover
        TableHead  ← <th> text-left h-10 px-4 font-medium text-muted-foreground
    TableBody    ← <tbody>
      TableRow   ← <tr> per data row
        TableCell  ← <td> p-4 align-middle (shadcn default — do NOT override)
```

### Phlex Usage

```ruby
div(class: "relative w-full overflow-auto") do
  render Components::Ui::Table.new do
    render Components::Ui::TableHeader.new do
      render Components::Ui::TableRow.new do
        render Components::Ui::TableHead.new { "Name" }
        render Components::Ui::TableHead.new { "Status" }
        render Components::Ui::TableHead.new(class: "text-right") { "Actions" }
      end
    end

    render Components::Ui::TableBody.new do
      @items.each do |item|
        render Components::Ui::TableRow.new do
          render Components::Ui::TableCell.new(class: "font-medium") { item.name }
          render Components::Ui::TableCell.new do
            render Components::Ui::Badge.new(variant: :default) { item.status }
          end
          render Components::Ui::TableCell.new(class: "text-right") do
            # action button/dropdown here
          end
        end
      end
    end
  end
end
```

### Critical Rules

**`align-middle` is the `TableCell` shadcn default — never override with `align-top`.**

**Never use `<p>` tags inside `TableCell`** — block-level boxes break `align-middle`.
- ✅ Plain text directly in `TableCell`
- ✅ `span(class: "block line-clamp-2 max-w-[36ch]")` for truncated multi-line text  
- ✅ `span(class: "italic")` for placeholder text
- ❌ `p(class: "font-medium") { text }` inside a cell

**Putting a class on `TableCell` instead of a wrapper:**
- ✅ `render Components::Ui::TableCell.new(class: "font-medium") { item.name }`
- ❌ `render Components::Ui::TableCell.new { p(class: "font-medium") { item.name } }`

### Per-Row Action Menus (Dropdown)

Use a ghost icon button (`MoreHorizontal`) as the trigger for a `DropdownMenuContent` scoped to its row:

```ruby
render Components::Ui::TableCell.new(class: "text-right") do
  render Components::Ui::DropdownMenu.new(
    data: { ui__dropdown_placement_value: "bottom-end" }
  ) do |dropdown|
    dropdown.trigger(variant: :ghost, size: :icon, class: "size-8") do
      render Components::Ui::Icon.new(:"more-horizontal", class: "h-4 w-4")
      span(class: "sr-only") { t("...menu_trigger") }
    end

    dropdown.content(hidden: true, align: :end) do
      dropdown.item(
        href: edit_path(item),
        data: { turbo_frame: "_top" }
      ) { "Edit" }

      dropdown.separator

      dropdown.item(
        href: item_path(item),
        variant: :destructive,
        data: {
          turbo_frame: "_top",
          turbo_method: :delete,
          turbo_confirm: "Are you sure?"
        }
      ) { "Delete" }
    end
  end
end
```

- Each row gets its own `data-controller="ui--dropdown"` scope — menus are independent.
- Use `data-turbo-method` and `data-turbo-confirm` on links, not `button_to` form helpers.
- Use `data-turbo-frame="_top"` on all action links inside dropdown items.
- For external links (e.g., "View in new tab"), add `target: "_blank"` and `rel: "noopener noreferrer"`.

### i18n Keys for Tables

Follow the fully-qualified key pattern. Standard table keys under `admin.{resource}.index`:

```yaml
# config/locales/en/{resource}.yml
en:
  admin:
    articles:
      index:
        title: "Articles"
        subtitle: "Manage and publish your articles"
        new_article: "New Article"
        empty_title: "No articles yet"
        empty_description: "Get started by creating your first article."
        columns:
          article: "Article"
          status: "Status"
          published: "Published"
          excerpt: "Excerpt"
          actions: "Actions"
        statuses:
          draft: "Draft"
          published: "Published"
          archived: "Archived"
        menu_trigger: "Open actions"
        not_published: "Not published"
        no_excerpt: "No excerpt"
```

---

## Card + Table Layout (shadcn Page Pattern)

The standard shadcn data-table page puts the header and table inside a **single Card**. Use `CardHeader` for the title/description + action button row, and `CardContent` with `p-0` so the table renders edge-to-edge:

```ruby
render Components::Ui::Card.new do
  # Header: title + description (left) | primary action (right)
  render Components::Ui::CardHeader.new(class: "flex flex-row items-center justify-between space-y-0") do
    div do
      render Components::Ui::CardTitle.new(as: :h1) { t("admin.articles.index.title") }
      render Components::Ui::CardDescription.new { t("admin.articles.index.subtitle") }
    end

    render Components::Ui::Button.new(as: :a, href: new_admin_article_path) { t("admin.articles.index.new_article") }
  end

  # Table (edge-to-edge, no inner padding)
  render Components::Ui::CardContent.new(class: "p-0") do
    div(class: "relative w-full overflow-auto") do
      render Components::Ui::Table.new do
        # ... TableHeader + TableBody
      end
    end
  end
end
```

**Key details:**
- `CardHeader` needs `flex flex-row items-center justify-between space-y-0` to override the default `flex-col space-y-1.5` and place the button on the right.
- `CardContent` needs `p-0` so the table border reaches the card edges (no inner padding gap).
- `CardTitle` supports `as: :h1` to use the correct heading level semantically while keeping the `CardTitle` style.
- Empty state also lives inside `CardContent` (same card, same padding override), so the card stays unified regardless of whether data exists.
