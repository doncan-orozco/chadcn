# frozen_string_literal: true

module Bench
  # Each scenario is a lambda returning a fresh Phlex view; `reference` hand-writes the exact HTML of `button` in plain Phlex inside
  # the same Block wrapper, so button minus reference is the component's own overhead.
  module Scenarios
    # Wraps a block as a Phlex view.
    class Block < Phlex::HTML
      def initialize(body)
        @body = body
        super()
      end

      def view_template = instance_exec(&@body)
    end

    # The outline Button's class string, copied from its rendered output; runner_test.rb keeps the reference equal to the component.
    REFERENCE_BUTTON_CLASS = "inline-flex shrink-0 items-center justify-center gap-2 rounded-md text-sm font-medium whitespace-nowrap transition-all outline-none focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50 disabled:pointer-events-none disabled:opacity-50 aria-invalid:border-destructive aria-invalid:ring-destructive/20 dark:aria-invalid:ring-destructive/40 [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4 border bg-background shadow-xs hover:bg-accent hover:text-accent-foreground dark:border-input dark:bg-input/30 dark:hover:bg-input/50 h-9 px-4 py-2 has-[>svg]:px-3".freeze

    # @return [Block] a view rendering the block
    def self.view(&body) = Block.new(body)

    ALL = {
      "reference" => lambda {
        view do
          button(data: { slot: "button", variant: "outline", size: "default" }, class: REFERENCE_BUTTON_CLASS) { "Save" }
        end
      },
      "button" => -> { view { render(Phlex::Shadcn::Button.new(variant: "outline")) { "Save" } } },
      "card" => lambda {
        view do
          render(Phlex::Shadcn::Card.new) do
            render(Phlex::Shadcn::Card::Header.new) do
              render(Phlex::Shadcn::Card::Title.new) { "Title" }
              render(Phlex::Shadcn::Card::Description.new) { "Description" }
            end
            render(Phlex::Shadcn::Card::Content.new) { "Body" }
            render(Phlex::Shadcn::Card::Footer.new) { "Footer" }
          end
        end
      },
      "select" => lambda {
        view do
          render(Phlex::Shadcn::Select.new) do
            render(Phlex::Shadcn::Select::Trigger.new) { render(Phlex::Shadcn::Select::Value.new(placeholder: "Pick")) }
            render(Phlex::Shadcn::Select::Content.new) do
              render(Phlex::Shadcn::Select::Group.new) do
                render(Phlex::Shadcn::Select::Label.new) { "Fruits" }
                %w[apple banana cherry].each { |fruit| render(Phlex::Shadcn::Select::Item.new(value: fruit)) { fruit.capitalize } }
              end
            end
          end
        end
      },
      "dialog" => lambda {
        view do
          render(Phlex::Shadcn::Dialog.new) do
            render(Phlex::Shadcn::Dialog::Trigger.new(as_child: Phlex::Shadcn::Button.new(variant: "outline"))) { "Open" }
            render(Phlex::Shadcn::Dialog::Content.new) do
              render(Phlex::Shadcn::Dialog::Header.new) do
                render(Phlex::Shadcn::Dialog::Title.new) { "Title" }
                render(Phlex::Shadcn::Dialog::Description.new) { "Description" }
              end
              render(Phlex::Shadcn::Dialog::Footer.new) { "Actions" }
            end
          end
        end
      },
      "table" => lambda {
        view do
          render(Phlex::Shadcn::Table.new) do
            render(Phlex::Shadcn::Table::Body.new) do
              50.times do |row_number|
                render(Phlex::Shadcn::Table::Row.new) do
                  render(Phlex::Shadcn::Table::Cell.new) { "Row #{row_number}" }
                  render(Phlex::Shadcn::Table::Cell.new) { render(Phlex::Shadcn::Button.new(size: "sm")) { "Edit" } }
                end
              end
            end
          end
        end
      }
    }.freeze
  end
end
