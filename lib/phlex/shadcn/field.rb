# frozen_string_literal: true

# shadcn Field (new-york-v4). Spec: docs/shadcn-port/specs/field.md. Static: no controller.
class Phlex::Shadcn::Field < Phlex::Shadcn::Base
  BASE = "group/field flex w-full gap-3 data-[invalid=true]:text-destructive"
  ORIENTATIONS = {
    "vertical" => "flex-col [&>*]:w-full [&>.sr-only]:w-auto",
    "horizontal" => "flex-row items-center [&>[data-slot=field-label]]:flex-auto has-[>[data-slot=field-content]]:items-start has-[>[data-slot=field-content]]:[&>[role=checkbox],[role=radio]]:mt-px",
    "responsive" => "flex-col @md/field-group:flex-row @md/field-group:items-center [&>*]:w-full @md/field-group:[&>*]:w-auto [&>.sr-only]:w-auto @md/field-group:[&>[data-slot=field-label]]:flex-auto @md/field-group:has-[>[data-slot=field-content]]:items-start @md/field-group:has-[>[data-slot=field-content]]:[&>[role=checkbox],[role=radio]]:mt-px"
  }.freeze

  # Mirrors the (unexported) `fieldVariants` cva of the tsx.
  def self.variants(orientation: "vertical", class: nil)
    new(orientation:).send(:cn, BASE, ORIENTATIONS[(orientation || "vertical").to_s], binding.local_variable_get(:class))
  end

  def initialize(orientation: "vertical", **attrs)
    @orientation = (orientation || "vertical").to_s
    @attrs = attrs
    super()
  end

  def view_template(&block)
    attrs = merge_attrs(
      { role: "group", data: { slot: "field", orientation: @orientation }, class: [ BASE, ORIENTATIONS[@orientation] ] },
      @attrs
    )
    div(**attrs) { yield self if block }
  end

  class Set < Phlex::Shadcn::Base
    CLASS_NAME = "flex flex-col gap-6 has-[>[data-slot=checkbox-group]]:gap-3 has-[>[data-slot=radio-group]]:gap-3"

    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    def view_template(&)
      fieldset(**merge_attrs({ data: { slot: "field-set" }, class: CLASS_NAME }, @attrs), &)
    end
  end

  class Legend < Phlex::Shadcn::Base
    CLASS_NAME = "mb-3 font-medium data-[variant=legend]:text-base data-[variant=label]:text-sm"

    def initialize(variant: "legend", **attrs)
      @variant = (variant || "legend").to_s
      @attrs = attrs
      super()
    end

    def view_template(&)
      legend(**merge_attrs({ data: { slot: "field-legend", variant: @variant }, class: CLASS_NAME }, @attrs), &)
    end
  end

  class Group < Phlex::Shadcn::Base
    CLASS_NAME = "group/field-group @container/field-group flex w-full flex-col gap-7 data-[slot=checkbox-group]:gap-3 [&>[data-slot=field-group]]:gap-4"

    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    def view_template(&)
      div(**merge_attrs({ data: { slot: "field-group" }, class: CLASS_NAME }, @attrs), &)
    end
  end

  class Content < Phlex::Shadcn::Base
    CLASS_NAME = "group/field-content flex flex-1 flex-col gap-1.5 leading-snug"

    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    def view_template(&)
      div(**merge_attrs({ data: { slot: "field-content" }, class: CLASS_NAME }, @attrs), &)
    end
  end

  class Label < Phlex::Shadcn::Base
    CLASS_NAME = "group/field-label peer/field-label flex w-fit gap-2 leading-snug group-data-[disabled=true]/field:opacity-50 has-[>[data-slot=field]]:w-full has-[>[data-slot=field]]:flex-col has-[>[data-slot=field]]:rounded-md has-[>[data-slot=field]]:border [&>*]:data-[slot=field]:p-4 has-data-[state=checked]:border-primary has-data-[state=checked]:bg-primary/5 dark:has-data-[state=checked]:bg-primary/10"

    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    def view_template(&)
      attrs = merge_attrs({ data: { slot: "field-label" }, class: CLASS_NAME }, @attrs)
      render(Phlex::Shadcn::Label.new(**attrs), &)
    end
  end

  class Title < Phlex::Shadcn::Base
    CLASS_NAME = "flex w-fit items-center gap-2 text-sm leading-snug font-medium group-data-[disabled=true]/field:opacity-50"

    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    # Same data-slot as Label, as in the tsx (field.tsx:131).
    def view_template(&)
      div(**merge_attrs({ data: { slot: "field-label" }, class: CLASS_NAME }, @attrs), &)
    end
  end

  class Description < Phlex::Shadcn::Base
    CLASS_NAME = "text-sm leading-normal font-normal text-muted-foreground group-has-[[data-orientation=horizontal]]/field:text-balance last:mt-0 nth-last-2:-mt-1 [[data-variant=legend]+&]:-mt-1.5 [&>a]:underline [&>a]:underline-offset-4 [&>a:hover]:text-primary"

    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    def view_template(&)
      p(**merge_attrs({ data: { slot: "field-description" }, class: CLASS_NAME }, @attrs), &)
    end
  end

  class Separator < Phlex::Shadcn::Base
    CLASS_NAME = "relative -my-2 h-5 text-sm group-data-[variant=outline]/field-group:-mb-2"
    CONTENT_CLASS_NAME = "relative mx-auto block w-fit bg-background px-2 text-muted-foreground"

    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    def view_template(&block)
      content = block ? capture(&block) : ""
      has_content = content.present?
      attrs = merge_attrs({ data: { slot: "field-separator", content: has_content.to_s }, class: CLASS_NAME }, @attrs)
      div(**attrs) do
        render Phlex::Shadcn::Separator.new(class: "absolute inset-0 top-1/2")
        span(class: CONTENT_CLASS_NAME, data: { slot: "field-separator-content" }) { raw safe(content) } if has_content
      end
    end
  end

  class Error < Phlex::Shadcn::Base
    CLASS_NAME = "text-sm font-normal text-destructive"

    def initialize(errors: nil, **attrs)
      @errors = errors
      @attrs = attrs
      super()
    end

    def view_template(&block)
      children = block ? capture(&block) : ""
      messages = children.present? ? [] : unique_messages
      return if children.blank? && messages.compact_blank.empty?

      div(**merge_attrs({ role: "alert", data: { slot: "field-error" }, class: CLASS_NAME }, @attrs)) do
        if children.present?
          raw safe(children)
        elsif messages.size == 1
          plain messages.first
        else
          ul(class: "ml-4 flex list-disc flex-col gap-1") { messages.compact_blank.each { |message| li { message } } }
        end
      end
    end

    private

    # Port of `new Map(errors.map(e => [e?.message, e])).values()`: dedupe by message, first occurrence order;
    # entries without a message share one key and render nothing.
    def unique_messages
      Array(@errors).map { |error| message_of(error) }.uniq
    end

    def message_of(error)
      return error[:message] || error["message"] if error.is_a?(Hash)

      error.message if error.respond_to?(:message)
    end
  end
end
