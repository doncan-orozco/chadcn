# frozen_string_literal: true

using Phlex::Shadcn::Values::Refinements

# Radix MenubarMenu: renders no element, it groups one {Trigger} with its {Content}. +value:+ identifies the menu for the
# root value; +nil+ (or blank) gets an auto value from the per-render counter. Modal is forced off by Radix and is not an
# option. Must be rendered inside a {Phlex::Shadcn::Menubar} (raises +ArgumentError+ at render otherwise).
#
# @example
#   bar.menu(value: "file") { bar.trigger { "File" }; bar.content { bar.item { "New" } } }
class Phlex::Shadcn::Menubar::Menu < Phlex::Shadcn::Base
  include Phlex::Shadcn::Menubar::Support

  # @param value [String, Symbol, nil] the menu's identifier, compared (as a String) with the root +value:+ / +default_value:+
  #   to decide whether it renders open. Default +nil+ (auto value)
  # @raise [ArgumentError] at render, when not inside a {Phlex::Shadcn::Menubar}
  def initialize(value: nil)
    @value = value&.to_s
    super()
  end

  # @yield the menu's {Trigger} and {Content}
  # @return [void]
  def view_template
    root = root_context
    previous = context[Phlex::Shadcn::Menubar::MENU_KEY]
    base = "#{root[:base]}-menu-#{Phlex::Shadcn::Menubar.next_sequence(context)}"
    value = @value.unless_blank || base
    context[Phlex::Shadcn::Menubar::MENU_KEY] = {
      value:, open: root[:value] == value, trigger_id: "#{base}-trigger", content_id: "#{base}-content", base:
    }
    yield if block_given?
  ensure
    context[Phlex::Shadcn::Menubar::MENU_KEY] = previous
  end
end
