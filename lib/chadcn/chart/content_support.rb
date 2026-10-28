# frozen_string_literal: true

# What {Chadcn::Chart::Tooltip::Content} and {Chadcn::Chart::Legend::Content} share: the content is built from one frozen
# `@options` hash and a validated payload, copied per tooltip index by {#with}, and reads the config of the enclosing
# {Chadcn::Chart::Container} (React's `useChart()`).
#
# @api private
module Chadcn::Chart::ContentSupport
  # Key of the render context a Tooltip or Legend publishes itself under while its block runs.
  #
  # @api private
  HOLDER_KEY = :chadcn_chart_content_holder

  # Runs the block with `holder` as the declaration a content written inside it registers with.
  #
  # @api private
  # @param context [Hash] the Phlex render context
  # @param holder [#adopt_content] a {Chadcn::Chart::Tooltip} or {Chadcn::Chart::Legend}
  # @return [Object] what the block returns
  def self.holding(context, holder)
    previous = context[HOLDER_KEY]
    context[HOLDER_KEY] = holder
    yield
  ensure
    previous ? context[HOLDER_KEY] = previous : context.delete(HOLDER_KEY)
  end

  # A copy with other options, e.g. the payload and label of one tooltip index.
  #
  # @api private
  # @return [Chadcn::Base]
  def with(**changes) = self.class.new(**@options.except(:attrs), **@options.fetch(:attrs), payload: @payload, **changes)

  private

  # Inside the block of a Tooltip or Legend the content is declared, not drawn: it hands itself to the declaration.
  def adopted?
    holder = context[Chadcn::Chart::ContentSupport::HOLDER_KEY] or return false
    holder.adopt_content(self)
    true
  end

  def option(name) = @options.fetch(name)

  # JS truthiness of a payload name: nil, false, "" and 0 are falsy.
  def js_truthy?(value) = ![ nil, false, "", 0 ].include?(value)

  # @param payload [Array<Hash>, nil] nil is an absent payload
  # @return [Array<Hash>]
  # @raise [ArgumentError] unless it is an Array of Hashes
  def validated_payload(payload)
    return [] if payload.nil?
    return payload if payload.is_a?(Array) && payload.all?(Hash)

    raise ArgumentError, "payload: must be an Array of Hashes (got #{payload.class})"
  end

  def chart_config
    container = Chadcn::Chart::Container.current(context)
    raise ArgumentError, "#{self.class.name} has no Chart::Container around it; React's useChart() raises the same" unless container

    container.config
  end

  # A payload item's value by symbol or string key.
  def item_value(item, key)
    item.fetch(key) { item[key.to_s] }
  end

  # Whether the item has the key at all, even with a nil value (JS `!== undefined`).
  def item_key?(item, key) = item.key?(key) || item.key?(key.to_s)

  def render_icon(icon)
    render(icon.is_a?(Phlex::SGML) ? icon : Chadcn::Icon.new(icon))
  end

  def render_node(node)
    case node
    when nil, false then nil
    when Phlex::SGML then render(node)
    else plain(node.to_s)
    end
  end
end
