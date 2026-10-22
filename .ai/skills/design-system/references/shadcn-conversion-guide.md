# shadcn Component Conversion Guide (Radix UI → Phlex)

**Purpose:** Step-by-step guide for converting shadcn Radix UI components to Phlex with pixel-perfect accuracy.

## Prerequisites

- [ ] Tailwind CSS v4 installed
- [ ] CSS variables configured (see [css-variables-guide.md](css-variables-guide.md))
- [ ] Phlex and phlex-rails installed
- [ ] `Components::Base` class exists in `app/components/base.rb`

## Conversion Process

### Step 1: Identify Source Component

1. Navigate to https://ui.shadcn.com/docs/components/[component-name]
2. **Verify it's Radix UI** (not Base UI) - check the installation tabs
3. Note the component variants and sizes listed in documentation

**Example:** For Button component, go to https://ui.shadcn.com/docs/components/button

### Step 2: Inspect Actual Rendered HTML

**CRITICAL:** Don't rely solely on the React source code - inspect the actual rendered HTML.

1. Open the shadcn documentation page with the component
2. Right-click on the rendered component → "Inspect Element"
3. Copy the complete rendered HTML with all classes
4. Take note of:
   - Exact class names (e.g., `bg-primary` not `bg-slate-900`)
   - Height values (e.g., `h-8` for buttons)
   - Border radius (e.g., `rounded-lg`)
   - Opacity modifiers (e.g., `bg-destructive/10`)
   - Focus ring thickness (e.g., `ring-3`)
   - Transition type (e.g., `transition-all`)
   - SVG handlers (e.g., `[&_svg]:size-4`)
   - ARIA state styling (e.g., `aria-invalid:ring-3`)

**Why this matters:** The React source often shows simplified class names, but the actual rendered output reveals:
- Semantic tokens with opacity modifiers
- Complete SVG handling classes
- ARIA state styling
- Icon spacing adjustments
- Dark mode variants

### Step 3: Extract Class Patterns

Group classes into logical categories:

```ruby
# Base classes (shared by all variants)
base_classes = [
  # Layout & positioning
  "inline-flex items-center justify-center whitespace-nowrap",
  
  # Interaction states
  "transition-all focus-visible:ring-3",
  "disabled:pointer-events-none disabled:opacity-50",
  
  # Core styling
  "rounded-lg border border-transparent bg-clip-padding",
  "text-sm font-medium outline-none select-none group/button",
  
  # SVG handling
  "[&_svg:not([class*='size-'])]:size-4",
  "[&_svg]:pointer-events-none",
  "shrink-0 [&_svg]:shrink-0",
  
  # ARIA states
  "aria-invalid:ring-3 aria-invalid:ring-destructive/20",
  "aria-invalid:border-destructive dark:aria-invalid:border-destructive/50"
].join(" ")

# Variant classes (different styles)
variant_classes = {
  default: "bg-primary text-primary-foreground hover:bg-primary/90",
  destructive: "bg-destructive/10 hover:bg-destructive/20 text-destructive",
  outline: "border-border bg-background hover:bg-muted",
  secondary: "bg-secondary text-secondary-foreground hover:bg-secondary/80",
  ghost: "hover:bg-muted text-foreground",
  link: "text-foreground underline-offset-4 hover:underline"
}

# Size classes (different dimensions)
size_classes = {
  default: "h-8 gap-1.5 px-2.5",
  xs: "h-6 gap-1 px-2 text-xs",
  sm: "h-8 gap-1.5 px-3",
  lg: "h-10 gap-2 px-4",
  icon: "h-8 w-8"
}
```

### Step 4: Create Phlex Component Structure

```ruby
# app/components/ui/[component_name].rb
module Components
  module Ui
    class [ComponentName] < Components::Base
      def initialize(variant: :default, size: :default, **attrs)
        @variant = variant
        @size = size
        @attrs = attrs
      end

      def view_template(&block)
        [html_element](class: classes, **@attrs, &block)
      end

      private

      def classes
        [
          base_classes,
          variant_classes[@variant],
          size_classes[@size]
        ].compact.join(" ")
      end

      def base_classes
        # Paste extracted base classes here
      end

      def variant_classes
        {
          # Paste extracted variants here
        }
      end

      def size_classes
        {
          # Paste extracted sizes here
        }
      end
    end
  end
end
```

### Step 5: Radix UI Verification Checklist

After creating the component, verify these Radix UI specifics:

#### Button Component
- [ ] Default height is `h-8` (32px) NOT `h-10` (40px - that's Base UI)
- [ ] Border radius is `rounded-lg` (8px) NOT `rounded-md` (6px)
- [ ] Focus ring is `ring-3` NOT `ring-2`
- [ ] Transition is `transition-all` NOT `transition-colors`
- [ ] Destructive uses `bg-destructive/10` (subtle) NOT `bg-red-500` (solid)

#### All Components
- [ ] Uses semantic tokens (`bg-primary`) NOT hardcoded colors (`bg-slate-900`)
- [ ] Includes SVG handling classes: `[&_svg:not([class*='size-'])]:size-4`
- [ ] Includes ARIA states: `aria-invalid:ring-3 aria-invalid:ring-destructive/20`
- [ ] Includes dark mode variants: `dark:bg-destructive/20`
- [ ] Includes opacity modifiers for subtle backgrounds: `/10`, `/20`, `/40`
- [ ] Passes through `**attrs` for Stimulus support
- [ ] Accepts `&block` for nested content
- [ ] Inherits from `Components::Base` NOT `Phlex::HTML`

### Step 6: CSS Variables Setup

Ensure CSS variables are defined for all semantic tokens used.

**Example tokens needed for Button:**
- `--color-primary`
- `--color-primary-foreground`
- `--color-destructive`
- `--color-secondary`
- `--color-secondary-foreground`
- `--color-muted`
- `--color-border`
- `--color-background`
- `--color-foreground`

See [css-variables-guide.md](css-variables-guide.md) for complete setup instructions.

### Step 7: Visual Comparison Testing

1. Start your Rails server: `bin/dev`
2. Create a test page with all component variants:

```ruby
# app/views/test/components.rb
module Views
  module Test
    class Components < Views::Base
      def view_template
        div(class: "p-8 space-y-8") do
          # Test all button variants
          div(class: "space-x-2") do
            render Components::Ui::Button.new(variant: :default) { "Default" }
            render Components::Ui::Button.new(variant: :destructive) { "Destructive" }
            render Components::Ui::Button.new(variant: :outline) { "Outline" }
            render Components::Ui::Button.new(variant: :secondary) { "Secondary" }
            render Components::Ui::Button.new(variant: :ghost) { "Ghost" }
            render Components::Ui::Button.new(variant: :link) { "Link" }
          end
          
          # Test all sizes
          div(class: "space-x-2") do
            render Components::Ui::Button.new(size: :xs) { "Extra Small" }
            render Components::Ui::Button.new(size: :sm) { "Small" }
            render Components::Ui::Button.new(size: :default) { "Default" }
            render Components::Ui::Button.new(size: :lg) { "Large" }
            render Components::Ui::Button.new(size: :icon) { "→" }
          end
        end
      end
    end
  end
end
```

3. Compare side-by-side with shadcn documentation:
   - Open shadcn docs: https://ui.shadcn.com/docs/components/button
   - Open your test page: http://localhost:3030/test/components
   - Check for pixel-perfect match:
     - [ ] Height matches (measure with browser DevTools)
     - [ ] Padding matches
     - [ ] Border radius matches
     - [ ] Background colors match (test all variants)
     - [ ] Text colors match
     - [ ] Hover states match
     - [ ] Focus rings match (thickness, color, opacity)
     - [ ] Disabled state matches

4. Test dark mode:
   - Toggle dark mode in your app
   - Verify all color tokens invert properly
   - Check destructive variant background remains subtle

## Common Pitfalls & Solutions

### Pitfall 1: Wrong Height/Sizing

**Problem:** Button looks too tall (40px instead of 32px)
```ruby
# WRONG - Base UI sizing
"h-10 px-4 py-2"
```

**Solution:** Use Radix UI sizing
```ruby
# CORRECT - Radix UI sizing
"h-8 gap-1.5 px-2.5"
```

### Pitfall 2: Hardcoded Colors

**Problem:** Button doesn't support theming, colors don't match
```ruby
# WRONG - Hardcoded colors
"bg-slate-900 text-white"
```

**Solution:** Use semantic tokens
```ruby
# CORRECT - Semantic tokens
"bg-primary text-primary-foreground"
```

### Pitfall 3: Harsh Destructive Variant

**Problem:** Destructive button has solid red background (too harsh)
```ruby
# WRONG - Solid background
"bg-red-500 text-white"
```

**Solution:** Use subtle background with opacity
```ruby
# CORRECT - Subtle background
"bg-destructive/10 hover:bg-destructive/20 text-destructive"
```

### Pitfall 4: Missing Border Radius

**Problem:** Button has wrong border radius (6px instead of 8px)
```ruby
# WRONG - rounded-md is 6px
"rounded-md"
```

**Solution:** Use rounded-lg for 8px
```ruby
# CORRECT - rounded-lg is 8px
"rounded-lg"
```

### Pitfall 5: Incomplete SVG Handling

**Problem:** Icons inside buttons have wrong size or block interactions
```ruby
# WRONG - No SVG handling
"inline-flex items-center"
```

**Solution:** Include complete SVG handlers
```ruby
# CORRECT - Complete SVG handling
[
  "inline-flex items-center",
  "[&_svg:not([class*='size-'])]:size-4",
  "[&_svg]:pointer-events-none",
  "shrink-0 [&_svg]:shrink-0"
].join(" ")
```

### Pitfall 6: Missing ARIA States

**Problem:** Invalid form fields don't show visual feedback
```ruby
# WRONG - No ARIA state handling
"border border-transparent"
```

**Solution:** Include ARIA invalid states
```ruby
# CORRECT - ARIA state handling
[
  "border border-transparent",
  "aria-invalid:ring-3 aria-invalid:ring-destructive/20",
  "aria-invalid:border-destructive"
].join(" ")
```

### Pitfall 7: Wrong Focus Ring

**Problem:** Focus ring is too thin (2px instead of 3px)
```ruby
# WRONG - ring-2 is too thin for Radix
"focus-visible:ring-2"
```

**Solution:** Use ring-3 for Radix UI
```ruby
# CORRECT - ring-3 matches Radix
"focus-visible:ring-3"
```

### Pitfall 8: Missing Dark Mode

**Problem:** Component doesn't adapt to dark mode
```ruby
# WRONG - No dark mode variants
"bg-destructive/10"
```

**Solution:** Include dark mode variants
```ruby
# CORRECT - Dark mode support
"bg-destructive/10 dark:bg-destructive/20"
```

## Troubleshooting

### Colors Don't Match

1. **Check CSS variables are defined**
   ```bash
   # Search for missing variables
   grep -r "@theme" app/assets/tailwind/
   ```

2. **Verify OKLCH format**
   ```css
   /* CORRECT OKLCH format */
   --color-primary: oklch(0.205 0 0);
   
   /* WRONG - hex format */
   --color-primary: #0f172a;
   ```

3. **Check color space in rendered output**
   - Open browser DevTools
   - Inspect button background-color
   - Should show OKLCH value, not hex

### Heights Don't Match

1. **Measure actual height**
   - Right-click button → Inspect
   - Check computed height in DevTools
   - shadcn Radix default button: 32px (h-8)

2. **Check for conflicting classes**
   ```ruby
   # Remove any py- classes from buttons
   "h-8 px-2.5"  # CORRECT - no py-*
   "h-10 px-4 py-2"  # WRONG - py-2 conflicts with h-10
   ```

### Border Radius Wrong

1. **Verify Tailwind class**
   - `rounded-lg` = 8px (Radix UI standard)
   - `rounded-md` = 6px (Base UI, wrong)
   - `rounded-[10px]` = 10px (custom, wrong)

2. **Check computed value in DevTools**
   - Should be exactly 8px
   - If different, check for CSS conflicts

### Focus Ring Not Showing

1. **Test keyboard navigation**
   - Tab to the button
   - Focus ring should appear (not just on click)

2. **Check focus-visible classes**
   ```ruby
   # CORRECT - uses focus-visible
   "focus-visible:ring-3 focus-visible:ring-primary/20"
   
   # WRONG - uses focus (always shows)
   "focus:ring-2"
   ```

## Verification Script

Run this in browser console to verify button specs:

```javascript
// Select button
const btn = document.querySelector('button');

// Get computed styles
const styles = window.getComputedStyle(btn);

console.log({
  height: styles.height,  // Should be "32px" for Radix default
  borderRadius: styles.borderRadius,  // Should be "8px"
  backgroundColor: styles.backgroundColor,  // Should be OKLCH
  fontSize: styles.fontSize,  // Should be "14px" (text-sm)
  fontWeight: styles.fontWeight,  // Should be "500" (font-medium)
});
```

Expected output for Radix button:
```
{
  height: "32px",
  borderRadius: "8px", 
  backgroundColor: "oklch(...)",
  fontSize: "14px",
  fontWeight: "500"
}
```

## Reference

- **shadcn Radix UI Button:** https://ui.shadcn.com/docs/components/button
- **Tailwind OKLCH Colors:** https://tailwindcss.com/docs/customizing-colors#using-css-variables
- **Complete Examples:** [design-system.md](design-system.md)
- **CSS Variables Setup:** [css-variables-guide.md](css-variables-guide.md)
