# frozen_string_literal: true

require "chadcn/test_case"

class Chadcn::Chart::Shape::Stack::GroupsTest < Chadcn::TestCase
  Groups = Chadcn::Chart::Shape::Stack::Groups

  test "by_id keeps the order of first appearance and stacks equal ids" do
    bars = [ { key: :a, id: "x" }, { key: :b, id: nil }, { key: :c, id: 1 }, { key: :d, id: "x" }, { key: :e, id: "1" }, { key: :f, id: nil } ]
    groups = Groups.by_id(bars) { |bar| bar[:id] }

    keys = groups.map { |group| group.map { |bar| bar[:key] } }

    assert_equal [ %i[a d], [ :b ], %i[c e], [ :f ] ], keys
  end

  test "no items give no groups" do
    assert_empty Groups.by_id([]) { |item| item }
  end
end
