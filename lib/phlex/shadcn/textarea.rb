# frozen_string_literal: true

# shadcn `Textarea` (new-york-v4). Spec: docs/shadcn-port/specs/textarea.md
#
# @example
#   render Phlex::Shadcn::Textarea.new(name: "bio", rows: 4, placeholder: "Tell us about you", default_value: user.bio)
class Phlex::Shadcn::Textarea < Phlex::Shadcn::Base
  # Classes of the `<textarea>`; a caller `class:` is merged last.
  # @return [String]
  BASE = "flex field-sizing-content min-h-16 w-full rounded-md border border-input bg-transparent px-3 py-2 text-base shadow-xs transition-[color,box-shadow] outline-none placeholder:text-muted-foreground focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50 disabled:cursor-not-allowed disabled:opacity-50 aria-invalid:border-destructive aria-invalid:ring-destructive/20 md:text-sm dark:bg-input/30 dark:aria-invalid:ring-destructive/40"

  # React value and defaultValue both render as the text content; value wins.
  #
  # @param default_value [#to_s, nil] initial text
  # @param value [#to_s, nil] text, takes precedence over `default_value`
  # @param attrs [Hash] HTML attributes for the `<textarea>` (`name:`, `rows:`, `class:` merged last, `aria:`)
  def initialize(default_value: nil, value: nil, **attrs)
    @text = value.nil? ? default_value : value
    @attrs = attrs
  end

  # @yield the text content, used only when neither `value:` nor `default_value:` is given
  # @return [void]
  def view_template(&block)
    attrs = merge_attrs({ data: { slot: "textarea" } }, @attrs.except(:class))
    textarea(**attrs, class: cn(BASE, @attrs[:class])) do
      if @text.nil?
        yield if block
      else
        plain @text.to_s
      end
    end
  end
end
