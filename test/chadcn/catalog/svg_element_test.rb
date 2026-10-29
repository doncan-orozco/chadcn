# frozen_string_literal: true

require "test_helper"

class Chadcn::Catalog::SvgElementTest < Minitest::Test
  def test_a_listed_tag_renders_with_its_attributes_spelled_by_phlex
    html = Chadcn::Catalog::SvgElement.new("linearGradient", id: "g").call { |_| }

    assert_includes html, '<linearGradient id="g">'
  end

  def test_stop_color_is_written_as_stop_dash_color
    html = Chadcn::Catalog::SvgElement.new("stop", offset: "5%", stop_color: "red").call

    assert_includes html, '<stop offset="5%" stop-color="red"></stop>'
  end

  def test_a_name_outside_the_list_raises
    %w[call render].each do |name|
      assert_raises(ArgumentError) { Chadcn::Catalog::SvgElement.new(name) }
    end
  end
end
