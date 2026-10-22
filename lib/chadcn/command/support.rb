# frozen_string_literal: true

# What the command parts share: the render context pushed by Command and the cmdk-wins attribute merge.
#
# @api private
module Chadcn::Command::Support
  private

  def root_context
    context[Chadcn::Command::CONTEXT_KEY] or raise ArgumentError, "#{self.class.name} must be used within Command"
  end

  # cmdk spreads some attributes AFTER the caller props, so the caller cannot override them: `forced` replaces the merged
  # top-level attributes, `aria`/`data` replace the matching keys of the merged hashes.
  def with_forced(attrs, forced = {}, aria: {}, data: {})
    attrs = attrs.merge(forced)
    attrs[:aria] = (attrs[:aria] || {}).merge(aria) unless aria.empty?
    attrs[:data] = (attrs[:data] || {}).merge(data) unless data.empty?
    attrs
  end

  def next_id(root, kind)
    root[kind] += 1
    "#{root[:base]}-#{kind.to_s.chomp('s')}-#{root[kind]}"
  end
end
