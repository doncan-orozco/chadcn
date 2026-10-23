# frozen_string_literal: true

require "chadcn/test_case"

# The counters behind the generated ids: per render in plain Phlex, per request once a sequence store is configured (the
# engine installs one; here a plain Hash stands in for it).
class Chadcn::SequenceTest < Chadcn::TestCase
  def fragment(html) = Nokogiri::HTML5.fragment(html)

  def content_ids(html) = fragment(html).css("[data-slot=dialog-content]").map { |content| content["id"] }

  def render_dialog = Chadcn::Dialog.new.call { |dialog| dialog.content { "x" } }

  def with_sequence_store(store)
    previous = Chadcn.config.sequence_store
    Chadcn.config.sequence_store = store
    yield
  ensure
    Chadcn.config.sequence_store = previous
  end

  test "without a sequence store every render numbers its roots from one" do
    assert_nil Chadcn.config.sequence_store
    assert_equal [ %w[dialog-1], %w[dialog-1] ], [ content_ids(render_dialog), content_ids(render_dialog) ]
  end

  test "with a sequence store the roots of separate renders are numbered in one sequence" do
    counters = {}
    ids = with_sequence_store(-> { counters }) { [ content_ids(render_dialog), content_ids(render_dialog) ] }

    assert_equal [ %w[dialog-1], %w[dialog-2] ], ids
    assert_equal({ Chadcn::Dialog::SEQUENCE_KEY => 2 }, counters)
  end

  test "a store that answers nil falls back to the render context" do
    ids = with_sequence_store(-> { }) { [ content_ids(render_dialog), content_ids(render_dialog) ] }

    assert_equal [ %w[dialog-1], %w[dialog-1] ], ids
  end

  test "each root class counts on its own" do
    counters = {}
    with_sequence_store(-> { counters }) do
      render_dialog
      Chadcn::Popover.new.call { |popover| popover.trigger { "x" } }
    end

    assert_equal({ Chadcn::Dialog::SEQUENCE_KEY => 1, Chadcn::Popover::SEQUENCE_KEY => 1 }, counters)
  end
end
