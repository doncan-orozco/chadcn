# frozen_string_literal: true

# shadcn/ui Direction over Radix Direction. Spec: docs/shadcn-port/specs/direction.md
# Namespace plus the use_direction helper; the provider part renders no element.
using Phlex::Shadcn::Values::Refinements

class Phlex::Shadcn::Direction < Phlex::Shadcn::Base
  KEY = :shadcn_direction
  VALUES = %w[ltr rtl].freeze

  # Radix useDirection: local dir, then nearest provider, then ltr. Never reads html dir.
  def self.use_direction(context, local_dir = nil)
    local = local_dir.to_s
    return local if local.filled?

    context[KEY].unless_blank || "ltr"
  end

  def view_template; end
end
