# frozen_string_literal: true

require "phlex/test_case"

class Phlex::Shadcn::TextareaTest < Phlex::Shadcn::TestCase
  test "renders slot and merges class" do
    html = Phlex::Shadcn::Textarea.new(class: "min-h-32", rows: 3, read_only: true, aria: { invalid: true }).call

    assert_includes html, 'data-slot="textarea"'
    assert_includes html, "min-h-32"
    refute_includes html, "min-h-16"
    assert_includes html, 'rows="3"'
    assert_includes html, "readonly"
    assert_includes html, 'aria-invalid="true"'
  end

  test "value, default_value and block render escaped text, value wins" do
    assert_includes Phlex::Shadcn::Textarea.new(default_value: "<a>").call, "&lt;a&gt;</textarea>"
    assert_includes Phlex::Shadcn::Textarea.new(default_value: "a", value: "b").call, ">b</textarea>"
    assert_includes Phlex::Shadcn::Textarea.new.call { "hi" }, ">hi</textarea>"
  end

  test "renders no text content without value or block" do
    assert_includes Phlex::Shadcn::Textarea.new(name: "bio").call, "></textarea>"
  end
end
