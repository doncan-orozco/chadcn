# frozen_string_literal: true

# VERIFIED REFERENCE for the `_base` task's DX helper generator (golden case 34 runs this file with plain `ruby`).
# Shows the three moving parts: (1) `Base.const_added` defines one helper per nested Base subclass, (2) the root yields itself,
# (3) a component that receives the yielded root (the legacy `Row.new(table: table)` pattern) can call the helpers.
# The real `Chadcn::Base` adds: attrs merging, `cn`, `render_as_child`, and the same collision check.
require "phlex"

module Proto
  class Base < Phlex::HTML
    # Ruby 3.2+: called for every constant assigned in a class body (the nested `class Header < Base` included).
    def self.const_added(name)
      super
      part = const_get(name) rescue nil
      return unless part.is_a?(Class) && part < Proto::Base

      helper = name.to_s.gsub(/([a-z\d])([A-Z])/, '\1_\2').downcase.to_sym
      if (Object.public_instance_methods + Phlex::HTML.public_instance_methods - Phlex::HTML::StandardElements.public_instance_methods - Phlex::HTML::VoidElements.public_instance_methods).include?(helper)
        raise ArgumentError, "helper #{helper} would override a Ruby/Phlex API method"
      end
      define_method(helper) { |**attrs, &block| render part.new(**attrs), &block }
    end
  end

  class Table < Base
    def initialize(**attrs) = @attrs = attrs
    def view_template(&block)
      div(class: "relative w-full overflow-auto") do
        tag(:table, class: "w-full", **@attrs) { yield self if block }   # root template uses tag(...) for names a helper shadows
      end
    end
    class Header < Base; def initialize(**a) = @a = a; def view_template(&b) = tag(:thead, **@a, &b); end
    class Body   < Base; def initialize(**a) = @a = a; def view_template(&b) = tag(:tbody, **@a, &b); end
    class Row    < Base; def initialize(**a) = @a = a; def view_template(&b) = tr(**@a, &b); end
    class Head   < Base; def initialize(**a) = @a = a; def view_template(&b) = th(**@a, &b); end
    class Cell   < Base; def initialize(**a) = @a = a; def view_template(&b) = td(**@a, &b); end
  end

  # the legacy pattern from the question: a row component that receives the yielded table
  class ArticleRow < Phlex::HTML
    def initialize(table:, article:) = (@table, @article = table, article)
    def view_template
      @table.row do
        @table.cell { @article[:title] }
        @table.cell(class: "text-right") { @article[:status] }
      end
    end
  end
end

articles = [{ title: "Slow thinking", status: "published" }, { title: "Draft", status: "draft" }]

helpers = Class.new(Phlex::HTML) do
  define_method(:view_template) do
    render Proto::Table.new(class: "text-sm") do |table|
      table.header { table.row { table.head { "Article" }; table.head(class: "text-right") { "Status" } } }
      table.body { articles.each { |a| render Proto::ArticleRow.new(table: table, article: a) } }
    end
  end
end

explicit = Class.new(Phlex::HTML) do
  define_method(:view_template) do
    render Proto::Table.new(class: "text-sm") do
      render(Proto::Table::Header.new) { render(Proto::Table::Row.new) { render(Proto::Table::Head.new) { "Article" }; render(Proto::Table::Head.new(class: "text-right")) { "Status" } } }
      render(Proto::Table::Body.new) { articles.each { |a| render(Proto::Table::Row.new) { render(Proto::Table::Cell.new) { a[:title] }; render(Proto::Table::Cell.new(class: "text-right")) { a[:status] } } } }
    end
  end
end

h, e = helpers.new.call, explicit.new.call
puts "IDENTICAL: #{h == e}"
puts "html: #{h}"
puts "GENERATED: #{(Proto::Table.public_instance_methods(false) - [:view_template]).sort.join(",")}"
begin
  Class.new(Proto::Base) { const_set(:Render, Class.new(Proto::Base)) }
  puts "COLLISION: not refused"
rescue ArgumentError => err
  puts "COLLISION: refused (#{err.message})"
end
puts "PLAIN_NESTED_GETS_HELPER: #{Class.new(Proto::Base) { const_set(:Plain, Class.new) }.public_instance_methods(false).include?(:plain)}"
