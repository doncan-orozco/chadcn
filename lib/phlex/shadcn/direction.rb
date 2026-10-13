# frozen_string_literal: true

# shadcn/ui Direction over Radix Direction. Spec: docs/shadcn-port/specs/direction.md
# Namespace plus the use_direction helper; the provider part renders no element.
class Phlex::Shadcn::Direction < Phlex::Shadcn::Base
  KEY = :v2_direction
  VALUES = %w[ltr rtl].freeze

  # Radix useDirection: local dir, then nearest provider, then ltr. Never reads html dir.
  def self.use_direction(context, local_dir = nil)
    local = local_dir.to_s
    return local if local.present?

    context[KEY].presence || "ltr"
  end

  def view_template; end
end
