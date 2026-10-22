# frozen_string_literal: true

using Chadcn::Values::Refinements

# Radix MenubarMenu: renders no element, it groups one {Trigger} with its {Content}. +value:+ identifies the menu for the
# root value; +nil+ (or blank) gets an auto value from the per-render counter. Modal is forced off by Radix and is not an
# option. Must be rendered inside a {Chadcn::Menubar} (raises +ArgumentError+ at render otherwise).
#
# @example
#   bar.menu(value: "file") { bar.trigger { "File" }; bar.content { bar.item { "New" } } }
class Chadcn::Menubar::Menu < Chadcn::Base
  include Chadcn::Menubar::Support

  # @param value [String, Symbol, nil] the menu's identifier, compared (as a String) with the root +value:+ / +default_value:+
  #   to decide whether it renders open. Default +nil+ (auto value)
  # @raise [ArgumentError] at render, when not inside a {Chadcn::Menubar}
  def initialize(value: nil)
    @value = value&.to_s
    super()
  end

  # @yield the menu's {Trigger} and {Content}
  # @return [void]
  def view_template
    root = root_context
    previous = context[Chadcn::Menubar::MENU_KEY]
    base = "#{root[:base]}-menu-#{Chadcn::Menubar.next_sequence(context)}"
    value = @value.unless_blank || base
    context[Chadcn::Menubar::MENU_KEY] = {
      value:, open: root[:value] == value, trigger_id: "#{base}-trigger", content_id: "#{base}-content", base:
    }
    yield if block_given?
  ensure
    context[Chadcn::Menubar::MENU_KEY] = previous
  end
end
