# frozen_string_literal: true

require "chadcn/test_case"

# Every root that generates ids takes `id:` through Base#validated_id (see test/chadcn/base_test.rb): a symbol is accepted and an
# id that cannot be one token (it seeds aria id lists and attribute selectors) raises at construction.
class Chadcn::RootIdTest < Chadcn::TestCase
  ROOTS = [
    Chadcn::Dialog, Chadcn::Sheet, Chadcn::AlertDialog, Chadcn::Popover, Chadcn::HoverCard, Chadcn::Tooltip,
    Chadcn::Tooltip::Provider, Chadcn::DropdownMenu, Chadcn::ContextMenu, Chadcn::Menubar, Chadcn::NavigationMenu,
    Chadcn::Collapsible, Chadcn::Accordion, Chadcn::Command, Chadcn::Sidebar::Provider, Chadcn::Select
  ].freeze

  INVALID_IDS = [ "", "a b", "a\tb", 'a"b', "a\\b" ].freeze

  ROOTS.each do |root|
    test "#{root.name} accepts a symbol id" do
      assert_instance_of root, root.new(id: :orders)
    end

    test "#{root.name} rejects an id that is not one token" do
      INVALID_IDS.each do |id|
        error = assert_raises(ArgumentError, "expected #{id.inspect} to raise") { root.new(id: id) }

        assert_includes error.message, "id:"
      end
    end
  end

  test "a symbol id renders like its string" do
    assert_equal Chadcn::Dialog.new(id: "orders").call, Chadcn::Dialog.new(id: :orders).call
    assert_includes Chadcn::Accordion.new(id: :faq).call, 'id="faq"'
  end
end
