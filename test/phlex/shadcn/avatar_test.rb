# frozen_string_literal: true

require "phlex/test_case"

class Phlex::Shadcn::AvatarTest < Phlex::Shadcn::TestCase
  Avatar = Phlex::Shadcn::Avatar

  def render_avatar(**props, &block)
    block ||= proc { |avatar| avatar.fallback { "CN" } }
    Avatar.new(**props).call(&block)
  end

  test "renders root with slot, size and a live fallback" do
    html = render_avatar

    assert_includes html, 'data-slot="avatar"'
    assert_includes html, 'data-size="default"'
    assert_includes html, 'data-controller="shadcn--avatar"'
    assert_includes html, '<span data-slot="avatar-fallback"'
    refute_includes html, "<template"
  end

  test "accepts size as symbol or string and rejects unknown sizes" do
    assert_includes render_avatar(size: :sm), 'data-size="sm"'
    assert_includes render_avatar(size: "lg"), 'data-size="lg"'
    assert_raises(ArgumentError) { Avatar.new(size: "xl") }
  end

  test "merges class and passes attrs through" do
    html = render_avatar(class: "size-12", id: "a1", aria: { label: "Me" })

    assert_includes html, "size-12"
    assert_includes html, 'id="a1"'
    assert_includes html, 'aria-label="Me"'
  end

  test "image is kept in a template and a delayed fallback waits in one" do
    html = render_avatar do |avatar|
      avatar.image src: "/a.png", alt: "me", referrer_policy: "no-referrer"
      avatar.fallback(delay_ms: 600) { "CN" }
    end

    assert_includes html, 'data-shadcn--avatar-target="image"'
    assert_includes html, 'src="/a.png"'
    assert_includes html, 'referrerpolicy="no-referrer"'
    assert_includes html, 'data-shadcn--avatar-delay-ms="600"'
  end

  test "as_child renders the given tag" do
    html = Avatar.new(as_child: :a, href: "/me").call { |avatar| avatar.fallback { "CN" } }

    assert_includes html, "<a "
    assert_includes html, 'href="/me"'
    assert_includes html, 'data-slot="avatar"'
  end

  test "every helper renders the same html as the explicit class call" do
    helpers = {
      badge: Avatar::Badge, group: Avatar::Group, group_count: Avatar::GroupCount, fallback: Avatar::Fallback
    }
    helpers.each do |helper, part|
      assert_respond_to Avatar.new, helper
      via_helper = Avatar.new.call { |avatar| avatar.public_send(helper, class: "x") { "t" } }
      explicit = Avatar.new.call { |avatar| avatar.render(part.new(class: "x")) { "t" } }

      assert_equal explicit, via_helper
    end
    assert_respond_to Avatar.new, :image
  end
end
