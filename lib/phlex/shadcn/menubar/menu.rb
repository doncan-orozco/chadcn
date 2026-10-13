# frozen_string_literal: true

# Radix MenubarMenu: renders no element. value: identifies the menu for the root value; nil gets an auto value from the
# per-render counter (Mb:97-98). Modal is forced off by Radix and is not an option.
using Phlex::Shadcn::Values::Refinements

class Phlex::Shadcn::Menubar::Menu < Phlex::Shadcn::Base
  include Phlex::Shadcn::Menubar::Support

  def initialize(value: nil)
    @value = value&.to_s
    super()
  end

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
