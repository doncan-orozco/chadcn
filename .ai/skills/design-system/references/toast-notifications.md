# Toast Notifications (Design System)

**Updated**: 2026-05-04

Toast notifications are auto-dismissing feedback messages displayed at the bottom-right of the screen. They replace inline alerts or banner-style messages for non-critical feedback.

## Pattern Overview

Toasts are triggered by:
- Form submission success/error (from controller flash)
- Async operation results (from AJAX responses)
- Real-time updates (from Action Cable broadcasts)

## Component Implementation

### Toast UI Component

The `Components::Ui::Toast` component is a shadcn/ui-compatible Phlex component that renders a dismissible notification with optional title, description, and icon.

```ruby
# app/components/ui/toast.rb
module Components
  module Ui
    class Toast < Components::Base
      def initialize(variant: :default, **attrs)
        @variant = variant # :default or :destructive
        @attrs = attrs
      end

      def view_template(&block)
        div(
          role: :status,
          aria: { live: "polite", atomic: true },
          class: merged_classes,
          **attrs_without_class,
        ) do
          yield self if block
        end
      end

      def title(**attrs, &block)
        render Title.new(**attrs), &block
      end

      def description(**attrs, &block)
        render Description.new(**attrs), &block
      end

      def close(**attrs, &block)
        render Close.new(**attrs), &block
      end

      private

      def classes
        [
          "group pointer-events-auto relative flex w-full items-center justify-between space-x-4 overflow-hidden rounded-md border border-border p-6 pr-8 shadow-lg transition-all",
          "data-[state=open]:animate-in data-[state=closed]:animate-out",
          "data-[state=closed]:fade-out-80 data-[state=closed]:slide-out-to-right-full data-[state=open]:slide-in-from-bottom-full data-[state=open]:sm:slide-in-from-top-full",
          @variant == :destructive ? "destructive group border-destructive bg-destructive text-destructive-foreground" : "border bg-background text-foreground"
        ].join(" ")
      end
    end

    class Toast::Title < Components::Base
      def view_template(&block)
        div(class: "text-sm font-semibold", **@attrs, &block)
      end
    end

    class Toast::Description < Components::Base
      def view_template(&block)
        div(class: "text-sm opacity-90", **@attrs, &block)
      end
    end

    class Toast::Close < Components::Base
      def initialize(**attrs)
        @attrs = attrs
      end

      def view_template(&block)
        # Button that allows Stimulus controller to bind close action
        render Components::Ui::Button.new(
          variant: :ghost,
          size: :sm,
          **@attrs,
          &block
        )
      end
    end
  end
end
```

### Global Flash Component

The `Components::Shared::Flash` component renders all flash messages as a stack of toasts in the bottom-right corner.

```ruby
# app/components/shared/flash.rb
module Components
  module Shared
    class Flash < Components::Base
      def initialize(flash:, **attrs)
        @flash = flash
        @attrs = attrs
      end

      def view_template
        return if messages.empty?

        div(class: "pointer-events-none fixed inset-x-0 bottom-4 z-[100] flex justify-end px-4 sm:inset-x-auto sm:right-4 sm:px-0") do
          div(class: "w-full max-w-sm space-y-2") do
            messages.each do |type, message|
              render_flash(type, message)
            end
          end
        end
      end

      private

      def messages
        @messages ||= [
          [:notice, @flash[:notice]],
          [:alert, @flash[:alert]]
        ].flat_map do |type, value|
          Array(value).compact_blank.map { |message| [type, message] }
        end
      end

      def render_flash(type, message)
        render Components::Ui::Toast.new(
          variant: toast_variant(type),
          class: "pointer-events-auto",
          data: {
            controller: "toast",
            toast_duration_value: 4000,
            state: "open"
          }
        ) do |toast|
          # Icon (optional)
          if type.to_sym == :alert
            render Components::Ui::Icon.new(:"alert-circle", class: "h-5 w-5")
          else
            render Components::Ui::Icon.new(:check, class: "h-5 w-5")
          end

          # Title and Message
          div(class: "grid gap-1") do
            toast.title { t("app.toasts.#{toast_title_key(type)}") }
            toast.description { message }
          end

          # Close Button
          toast.close(
            data: { action: "toast#dismiss" },
            aria: { label: t("app.toasts.close") }
          )
        end
      end

      def toast_variant(type)
        type.to_sym == :alert ? :destructive : :default
      end

      def toast_title_key(type)
        type.to_sym == :alert ? "error" : "success"
      end
    end
  end
end
```

### Stimulus Controller

The `toast_controller.js` handles auto-dismiss (4 seconds) and manual close animation.

```javascript
// app/javascript/controllers/toast_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { duration: { type: Number, default: 4000 } }

  connect() {
    this.timeout = setTimeout(() => this.dismiss(), this.durationValue)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }

  dismiss(event) {
    event?.preventDefault()
    clearTimeout(this.timeout)
    this.element.setAttribute("data-state", "closed")
    this.element.classList.add("opacity-0", "scale-95")
    setTimeout(() => this.element.remove(), 300)
  }
}
```

## Integration with Controller Flash

In controllers, flash messages automatically render via the global `Flash` component:

```ruby
# app/controllers/articles_controller.rb
def create
  result = Articles::Operation::Create.new.call(params: params.to_unsafe_h)

  if result.success?
    redirect_to article_path(result.model), notice: t("articles.operations.create.success")
  else
    flash.now[:alert] = t("articles.operations.create.failure")
    render :new, status: :unprocessable_entity
  end
end
```

The layout renders the flash component once:

```ruby
# app/views/layouts/application.rb
module Views
  module Layouts
    class Application < Views::Base
      def view_template(&block)
        html do
          head { yield :head }
          body do
            render Components::Shared::Flash.new(flash: flash)
            yield
          end
        end
      end
    end
  end
end
```

## I18n Keys

Notification labels are translated under `app.toasts`:

```yaml
# config/locales/en/app.yml
en:
  app:
    toasts:
      success: "Success"
      error: "Error"
      close: "Close"
```

```yaml
# config/locales/es/app.yml
es:
  app:
    toasts:
      success: "Éxito"
      error: "Error"
      close: "Cerrar"
```

Message content comes from operation/controller keys (e.g., `articles.operations.create.success`).

## Testing Toast Notifications

### Integration Tests (Controller Flash)

Test flash messages by asserting the toast role and content:

```ruby
# test/controllers/articles_controller_test.rb
test "create redirects with success toast" do
  post articles_path, params: { article: valid_params }

  assert_redirected_to article_path(@article)
  
  follow_redirect!
  
  # Toast renders as div[role=status] in the layout
  assert_select "div[role=status]", /#{I18n.t("articles.operations.create.success")}/
end
```

### Component Unit Tests

Test the Toast component and Flash wrapper separately:

```ruby
# test/components/shared/flash_test.rb
test "flash renders notice as default toast variant" do
  flash = { notice: "Article saved" }
  
  render_inline Components::Shared::Flash.new(flash: flash)
  
  assert_text "Success"  # toast title
  assert_text "Article saved"  # message content
  assert_selector "[data-controller='toast']"
  assert_selector "[data-state='open']"
end

test "flash renders alert as destructive toast variant" do
  flash = { alert: "Error occurred" }
  
  render_inline Components::Shared::Flash.new(flash: flash)
  
  assert_text "Error"  # toast title (destructive)
  assert_text "Error occurred"
  assert_selector "[class*='destructive']"
end
```

### System Tests (Full Flow)

Verify toast behavior in rendered pages:

```ruby
# test/system/articles/create_flow_test.rb
test "user sees success toast after creating article" do
  visit new_article_path
  fill_in "Title", with: "New Article"
  click_button "Create"
  
  assert_current_path article_path(@article)
  
  # Toast is visible with accessibility attributes
  assert_selector "[role='status'][aria-live='polite']", text: "Success"
end
```

## Best Practices

1. **Use for Non-Critical Feedback**: Toasts are for confirmation, success, or soft errors. Use page-level alerts for critical errors that block workflow.
2. **Keep Messages Short**: Toast descriptions should be 1-2 sentences max.
3. **Auto-Dismiss Appropriately**: 4 seconds is standard for success. Consider longer for errors or make them persistent.
4. **Avoid Toast Spam**: Batch multiple operations; don't show 10 toasts at once.
5. **Test Accessibility**: Verify `aria-live="polite"` and `role="status"` work in screen readers.
6. **Respect User Preference**: Consider respecting `prefers-reduced-motion` for animations.
