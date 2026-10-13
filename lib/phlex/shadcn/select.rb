# frozen_string_literal: true

# shadcn Select (Radix Select). Spec: docs/shadcn-port/specs/select.md. Behavior lives in controllers/shadcn/select_controller.js
# (hosted by the Trigger).
#
# Root renders no element: it pushes its state into the Phlex render context for the parts inside. Radix keeps the closed
# Content in a detached fragment so the items register and the text of the selected item reaches Value before anything opens; the
# server has no fragment, so the block is rendered twice: a first pass where only the Items register themselves (value, text,
# html) and a second pass that renders the DOM with that registry known.
class Phlex::Shadcn::Select < Phlex::Shadcn::Base
  include Phlex::Shadcn::Direction::Consumer

  ROOT_KEY = :shadcn_select_root
  GROUP_KEY = :shadcn_select_group
  SEQUENCE_KEY = :shadcn_select_sequence
  DIRECTIONS = %w[ltr rtl].freeze

  # value:/open: given (not nil) are controlled: user actions only dispatch events, the server decides the state.
  def initialize(value: nil, default_value: nil, open: nil, default_open: false, dir: nil, name: nil, auto_complete: nil,
                 form: nil, disabled: false, required: nil, id: nil)
    @options = {
      controlled_value: !value.nil?, value: (value.nil? ? default_value : value)&.to_s,
      controlled_open: !open.nil?, open: open.nil? ? default_open : open,
      dir: (dir.to_s if DIRECTIONS.include?(dir.to_s)),
      name:, auto_complete:, form:, disabled:, required:, base: id
    }
    super()
  end

  def view_template(&block)
    previous = context[ROOT_KEY]
    state = context[ROOT_KEY] =
      @options.merge(dir: use_direction(@options[:dir]), base: @options[:base] || "select-#{next_sequence}", known: [], phase: :collect)
    if block
      capture { yield self }
      state[:phase] = :render
      state[:counter] = 0
      yield self
    end
  ensure
    context[ROOT_KEY] = previous
  end

  private

  # Per render counter (no SecureRandom): ids are only compared through their relations.
  def next_sequence = context[SEQUENCE_KEY] = context.fetch(SEQUENCE_KEY, 0) + 1
end
