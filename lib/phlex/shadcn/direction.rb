# frozen_string_literal: true

using Phlex::Shadcn::Values::Refinements

# shadcn/ui Direction over Radix Direction. Spec: docs/shadcn-port/specs/direction.md
# Namespace plus the use_direction helper; the provider part renders no element.
#
# Wrap a subtree in {Provider} to set the direction its parts read through {Consumer}; use
# {Phlex::Shadcn::Direction.use_direction} from your own components. The default direction is `ltr` (the document `dir` is never read).
#
# @example Set the direction of a subtree
#   render Phlex::Shadcn::Direction::Provider.new(direction: :rtl) do
#     render Phlex::Shadcn::Tabs.new(default_value: "a") { |tabs| tabs.list { tabs.trigger(value: "a") { plain "A" } } }
#   end
# @example Read the direction in a component
#   class DirectionLabel < Phlex::Shadcn::Base
#     def view_template = span { Phlex::Shadcn::Direction.use_direction(context) }
#   end
#   render Phlex::Shadcn::Direction::Provider.new(dir: "rtl") { render DirectionLabel.new } # => <span>rtl</span>
#
# @see Phlex::Shadcn::Direction::Provider
# @see Phlex::Shadcn::Direction::Consumer
class Phlex::Shadcn::Direction < Phlex::Shadcn::Base
  # Render-context key holding the direction of the nearest provider.
  #
  # @api private
  KEY = :shadcn_direction
  # Accepted directions.
  VALUES = %w[ltr rtl].freeze

  # Radix useDirection: local dir, then nearest provider, then ltr. Never reads html dir.
  #
  # @param context [Hash] the render context of the calling component (`context` inside a Phlex component)
  # @param local_dir [String, Symbol, nil] direction set on the component itself, wins when present (default: nil)
  # @return [String] `"ltr"` or `"rtl"`
  def self.use_direction(context, local_dir = nil)
    local = local_dir.to_s
    return local if local.filled?

    context[KEY].unless_blank || "ltr"
  end

  # Renders nothing: Direction is a namespace, the provider part is {Provider}.
  #
  # @return [void]
  def view_template; end
end
