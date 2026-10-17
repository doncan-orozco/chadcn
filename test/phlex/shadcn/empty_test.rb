# frozen_string_literal: true

require "phlex/test_case"

class Phlex::Shadcn::EmptyTest < Phlex::Shadcn::TestCase
  def html(**, &block)
    Phlex::Shadcn::Empty.new(**).call(&block || proc { |_| "Body" })
  end

  test "root renders slot and merges class" do
    out = html(class: "p-2", id: "e")

    assert_includes out, 'data-slot="empty"'
    assert_includes out, 'id="e"'
    assert_not_includes out.slice(/class="([^"]*)"/, 1).split, "p-6"
  end

  test "media variants" do
    default = Phlex::Shadcn::Empty::Media.new(variant: :default).call { "x" }
    icon = Phlex::Shadcn::Empty::Media.new(variant: "icon").call { "x" }

    assert_includes default, 'data-slot="empty-icon"'
    assert_includes default, 'data-variant="default"'
    assert_includes default, "bg-transparent"
    assert_includes icon, 'data-variant="icon"'
    assert_includes icon, "bg-muted"
    assert_equal Phlex::Shadcn::Empty::Media.variants(variant: :icon), Phlex::Shadcn::Empty::Media.variants(variant: "icon")
    assert_raises(ArgumentError) { Phlex::Shadcn::Empty::Media.new(variant: :nope) }
  end

  test "helpers render the same HTML as the explicit classes" do
    helpers = html do |e|
      e.header { e.title { "T" } }
      e.media(variant: :icon) { "i" }
      e.description { "D" }
      e.content { "C" }
    end
    explicit = html do |e|
      e.render(Phlex::Shadcn::Empty::Header.new) { e.render(Phlex::Shadcn::Empty::Title.new) { "T" } }
      e.render(Phlex::Shadcn::Empty::Media.new(variant: :icon)) { "i" }
      e.render(Phlex::Shadcn::Empty::Description.new) { "D" }
      e.render(Phlex::Shadcn::Empty::Content.new) { "C" }
    end

    assert_equal explicit, helpers
  end

  test "media variants helper returns the class string and merges extra classes last" do
    out = Phlex::Shadcn::Empty::Media.variants(variant: :icon, class: "size-12")

    assert_includes out, "bg-muted"
    assert_includes out, "size-12"
    assert_not_includes out, "flex size-10"
    assert_raises(ArgumentError) { Phlex::Shadcn::Empty::Media.variants(variant: :nope) }
  end
end
