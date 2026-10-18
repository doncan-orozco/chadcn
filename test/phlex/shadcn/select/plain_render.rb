# frozen_string_literal: true

# Run in a subprocess by plain_render_test.rb: renders a Select whose Items hold real markup (nested elements, an icon whose
# attribute contains ">", entities) in plain Phlex, then reports what was loaded. The HTML printed after the marker line is
# compared with plain_render.html, recorded while Select::Item still read the text with Nokogiri.
require "phlex/shadcn"

class PlainSelect < Phlex::HTML
  Select = Phlex::Shadcn::Select

  def view_template
    render(Select.new(default_value: "b", name: "fruit", form: "f")) do
      render(Select::Trigger.new) { render(Select::Value.new(placeholder: "Pick")) }
      render(Select::Content.new) do
        render(Select::Item.new(value: "a")) do
          span { "Apple & <Pear> " }
          b { "ripe" }
        end
        render(Select::Item.new(value: "b", disabled: true)) { plain "  Banana &#233; " }
        render(Select::Item.new(value: "c", text_value: "Cherry")) do
          svg(data: { x: "a>b" }, aria_hidden: "true") { |s| s.path(d: "M0 0") }
          plain "Cherry"
        end
      end
    end
  end
end

html = PlainSelect.new.call
puts "nokogiri=#{defined?(Nokogiri) ? 'loaded' : 'absent'} rails=#{defined?(Rails) ? 'loaded' : 'absent'}"
print html
