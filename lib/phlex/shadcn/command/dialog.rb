# frozen_string_literal: true

# shadcn CommandDialog: a Command inside a Dialog (Phlex::Shadcn::Dialog does all the dialog behavior).
#
# `class:` goes to the dialog content; the other attributes, `open:`, `default_open:` and `modal:` go to the Dialog root.
# The block receives the Command root (so `command.input`, `command.list`... work).
#
# @example
#   render Phlex::Shadcn::Command::Dialog.new(default_open: true) do |command|
#     command.input(placeholder: "Type a command or search...")
#     command.list { command.empty { "No results found." } }
#   end
class Phlex::Shadcn::Command::Dialog < Phlex::Shadcn::Base
  # @param title [String] the sr-only dialog title
  # @param description [String] the sr-only dialog description
  # @param show_close_button [Boolean] render the X close button
  # @param open [Boolean, nil] controlled open state when not nil
  # @param default_open [Boolean] initial open state when uncontrolled
  # @param modal [Boolean] modal dialog (default true)
  # @param attrs [Hash] `class:` for the content; any other attribute for the Dialog root
  def initialize(title: "Command Palette", description: "Search for a command to run...", show_close_button: true, open: nil,
                 default_open: false, modal: true, **attrs)
    @title = title
    @description = description
    @show_close_button = show_close_button
    @dialog = { open: open, default_open: default_open, modal: modal }
    @attrs = attrs
    super()
  end

  # @yieldparam command [Phlex::Shadcn::Command] the Command root inside the dialog
  # @return [void]
  def view_template(&block)
    render Phlex::Shadcn::Dialog.new(**@dialog, **@attrs.except(:class)) do
      render(Phlex::Shadcn::Dialog::Header.new(class: "sr-only")) do
        render(Phlex::Shadcn::Dialog::Title.new { @title })
        render(Phlex::Shadcn::Dialog::Description.new { @description })
      end
      render Phlex::Shadcn::Dialog::Content.new(class: cn("overflow-hidden p-0", @attrs[:class]), show_close_button: @show_close_button) do
        render Phlex::Shadcn::Command.new(class: Phlex::Shadcn::Command::DIALOG_COMMAND_CLASSES), &block
      end
    end
  end
end
