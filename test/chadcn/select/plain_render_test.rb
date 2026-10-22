# frozen_string_literal: true

require "open3"
require "rbconfig"
require "test_helper"

# The README's non-Rails path: Select::Item must render without Nokogiri (a development dependency only). plain_render.rb runs in
# a subprocess that loads neither Nokogiri nor Rails; its HTML must equal the output recorded while the Item still used Nokogiri.
class Chadcn::Select::PlainRenderTest < Minitest::Test
  DIR = File.expand_path(__dir__)
  LIB = File.expand_path("../../../lib", __dir__)

  def setup
    @out, @err, @status = Open3.capture3(RbConfig.ruby, "-I", LIB, File.join(DIR, "plain_render.rb"))
    @marker, @html = @out.split("\n", 2)
  end

  def test_renders_in_plain_ruby_without_nokogiri_or_rails
    assert_predicate @status, :success?, @err
    assert_equal "nokogiri=absent rails=absent", @marker
  end

  def test_html_matches_the_output_recorded_with_nokogiri
    assert_equal File.read(File.join(DIR, "plain_render.html")), @html
  end

  def test_item_markup_becomes_the_plain_text_of_the_native_option
    options = @html.scan(%r{<option[^>]*>([^<]*)</option>}).flatten

    assert_includes options, "Apple &amp; &lt;Pear&gt; ripe"
    assert_includes options, "Cherry"
  end
end
