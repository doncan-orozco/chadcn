# frozen_string_literal: true

require "nokogiri"

module ChartSpike
  # Structural comparison of two HTML fragments (the committed oracle and the Phlex render), no browser involved.
  #
  # Contract (fixed in dev/decisions/chart.md, the G2 gate uses the same one):
  #   - tag names, the element tree (order and count), text nodes, attribute NAME sets and every non-numeric attribute are EXACT;
  #   - NUMERIC attributes are compared number by number within TOLERANCE after checking that the text around the numbers is identical:
  #     d, points, x, y, width, height, transform, x1, x2, y1, y2, cx, cy, r, and the length values inside style;
  #   - id values are replaced by their order of appearance (React.useId / recharts' counters are not reproducible), and `url(#id)`
  #     references go through the same table, so a reference to an id that does not exist on the other side fails;
  #   - the position of the tooltip wrapper (its style and the -top/-right/... class modifiers) is the controller's job and not compared;
  #   - NOT COMPARED (Stimulus wiring, absent from recharts): the attributes .claude/scripts/shadcn/parity_run.mjs already ignores for the
  #     wiring (IGNORED_ATTR, its data-* part: data-controller, data-action, data-turbo*, data-*-target, data-*-value, data-*-class, data-parity*,
  #     data-chadcn--*; its class/style/id/aria-* entries are NOT exempt here: class and id are part of this contract) and the tooltip
  #     `<template data-chadcn--chart-target="tooltipTemplate|tickTemplate">` children of div[data-slot="chart"]: the tooltip ones are compared
  #     once activated, through .recharts-tooltip-wrapper; the tick ones hold the labels the server hid (recharts omits hidden ticks and the
  #     controller mounts them, it never toggles visibility).
  class Compare
    TOLERANCE = 1e-3 # px: below one thousandth of a CSS pixel, above float noise (1e-13) and d3-path's 3-decimal rounding (5e-4)
    NUMERIC_ATTRIBUTES = %w[d points x y width height transform x1 x2 y1 y2 cx cy r style].freeze
    NUMBER = /-?\d+(?:\.\d+)?(?:e-?\d+)?/
    CHART_TEMPLATES = %w[tooltipTemplate tickTemplate].freeze
    POSITION_CLASS = /\Arecharts-tooltip-wrapper-/
    STIMULUS_ATTRIBUTE = /\A(?:data-controller|data-action|data-turbo.*|data-.*-target|data-.*-value|data-.*-class|data-parity.*|data-chadcn--.*)\z/
    URL_REFERENCE = /url\(#([^)]+)\)/

    Deviation = Struct.new(:path, :attribute, :amount)

    attr_reader :deviations, :errors

    def initialize(expected_html, actual_html, tolerance: TOLERANCE)
      @tolerance = tolerance
      @deviations = []
      @errors = []
      @ids = [ {}, {} ]
      walk(parse(expected_html), parse(actual_html), "")
    end

    def ok? = @errors.empty?

    def max_deviation = @deviations.max_by(&:amount)

    def compared_attributes = @deviations.size

    private

    def parse(html) = Nokogiri::HTML5.fragment(html.strip)

    def label(node) = node.text? ? "#text" : node.name

    def children(node)
      node.children.reject { |c| (c.text? && c.text.strip.empty?) || chart_template?(node, c) }
    end

    def chart_template?(parent, child)
      return false unless child.element? && child.name == "template" && parent.element? && parent.name == "div" && parent["data-slot"] == "chart"

      CHART_TEMPLATES.include?(child["data-chadcn--chart-target"].to_s)
    end

    def attribute_names(node) = node.attribute_nodes.map(&:name).grep_v(STIMULUS_ATTRIBUTE).sort

    def walk(expected, actual, path)
      here = "#{path}/#{label(expected)}"
      return error(here, "node type #{label(expected)} != #{label(actual)}") unless label(expected) == label(actual)
      return compare_text(expected, actual, here) if expected.text?

      compare_attributes(expected, actual, here) if expected.element?
      expected_children = children(expected)
      actual_children = children(actual)
      error(here, "child count #{expected_children.size} != #{actual_children.size}") unless expected_children.size == actual_children.size
      expected_children.zip(actual_children).each_with_index do |(e, a), i|
        walk(e, a, "#{here}[#{i}]") if a
      end
    end

    def compare_text(expected, actual, here)
      error(here, "text #{expected.text.strip.inspect} != #{actual.text.strip.inspect}") unless expected.text.strip == actual.text.strip
    end

    def compare_attributes(expected, actual, here)
      tooltip_wrapper = expected["class"].to_s.split.include?("recharts-tooltip-wrapper")
      names = attribute_names(expected)
      actual_names = attribute_names(actual)
      error(here, "attribute names #{names} != #{actual_names}") unless names == actual_names
      (names & actual_names).each do |name|
        next if tooltip_wrapper && name == "style"

        compare_attribute(name, expected[name], actual[name], "#{here}@#{name}", tooltip_wrapper)
      end
    end

    def compare_attribute(name, expected, actual, here, tooltip_wrapper)
      if name == "id"
        compare_id(expected, actual, here)
      elsif name == "class" && tooltip_wrapper
        error(here, "class #{expected} != #{actual}") unless without_position(expected) == without_position(actual)
      elsif NUMERIC_ATTRIBUTES.include?(name)
        compare_numbers(name, expected, actual, here)
      elsif normalize_references(expected, 0) != normalize_references(actual, 1)
        error(here, "#{expected.inspect} != #{actual.inspect}")
      end
    end

    def without_position(value) = value.split.grep_v(POSITION_CLASS)

    def id_order(side, value) = (@ids[side][value] ||= @ids[side].size)

    def normalize_references(value, side)
      value.gsub(URL_REFERENCE) { "url(#id#{id_order(side, Regexp.last_match(1))})" }.gsub(/#recharts[\w-]*/, "#ID")
    end

    def compare_id(expected, actual, here)
      a = id_order(0, expected)
      b = id_order(1, actual)
      error(here, "id #{expected} (#{a}) != #{actual} (#{b})") unless a == b
    end

    def compare_numbers(name, expected, actual, here)
      skeleton = ->(s) { s.gsub(NUMBER, "#").gsub(/\s+/, " ").strip }
      return error(here, "#{expected.inspect} != #{actual.inspect} (text around the numbers)") unless skeleton.call(expected) == skeleton.call(actual)

      pairs = expected.scan(NUMBER).map(&:to_f).zip(actual.scan(NUMBER).map(&:to_f))
      worst = pairs.map { |e, a| (e - a).abs }.max || 0.0
      @deviations << Deviation.new(here, name, worst)
      error(here, "#{expected.inspect} != #{actual.inspect} (deviation #{worst} > #{@tolerance})") if worst > @tolerance
    end

    def error(here, message) = @errors << "#{here}: #{message}"
  end
end
