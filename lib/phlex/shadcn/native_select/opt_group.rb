# frozen_string_literal: true

class Phlex::Shadcn::NativeSelect
  # An `<optgroup>` wrapping {Option}s.
  #
  # @example
  #   select.opt_group(label: "Staff") { select.option(value: "editor") { "Editor" } }
  class OptGroup < Phlex::Shadcn::Base
    # @param attrs [Hash] HTML attributes for the `<optgroup>` (`label:`, `disabled:`, `class:`)
    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    # @yield the options of the group
    # @return [void]
    def view_template(&)
      optgroup(**merge_attrs({ class: "bg-[Canvas] text-[CanvasText]", data: { slot: "native-select-optgroup" } }, @attrs), &)
    end
  end
end
