# frozen_string_literal: true

using Phlex::Shadcn::Values::Refinements

# What the sidebar parts share: the as_child switch and the default/caller attribute merge.
#
# @api private
module Phlex::Shadcn::Sidebar::Support
  # Stimulus action descriptor that toggles the sidebar.
  #
  # @api private
  TOGGLE = "click->shadcn--sidebar#toggle"

  private

  def render_part(tag_name, as_child, attrs, &)
    return render_as_child(as_child, **attrs, &) if as_child

    tag(tag_name, **attrs, &)
  end

  # Defaults of a part (class, data, other attributes) merged with the caller attributes.
  def part_attrs(classes, **defaults)
    merge_attrs({ class: classes }.merge(defaults), @attrs)
  end

  # The built-in toggle runs AFTER the caller own actions (tsx:270-273 `onClick?.(event); toggleSidebar()`).
  def with_toggle(attrs)
    data = attrs[:data] || {}
    attrs.merge(data: data.merge(action: [ data[:action], TOGGLE ].reject_blank.join(" ")))
  end
end
