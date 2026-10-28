# frozen_string_literal: true

# What recharts' `Text` does with a label, with the browser's measurement replaced by the server's assumption (a fixed character width
# and line height, `Chart::Container#text_char_width` / `#text_height`; `chadcn--chart` re-measures): the words broken into lines for a
# given width (`getWordsByLines`, component/Text.js) and the `dy` of the first line for a vertical anchor.
#
# @api private
class Chadcn::Chart::Cartesian::Text
  # The assumed font size in px; `text_char_width` is in em of it.
  FONT_SIZE = 12.0
  BREAKING_SPACES = /[ \f\n\r\t\v  ]+/

  private_constant :FONT_SIZE, :BREAKING_SPACES

  # @api private
  # @return [Float] the assumed height of one line of text, px
  attr_reader :line_height

  # @api private
  # @param char_width [Numeric] width of a character, em
  # @param line_height [Numeric] height of a line, px
  def initialize(char_width: 0.6, line_height: 16)
    @char_width = char_width * FONT_SIZE
    @line_height = line_height.to_f
    freeze
  end

  # `getStringSize(text).width`.
  #
  # @api private
  # @param text [String, nil]
  # @return [Float]
  def width(text) = text.to_s.length * @char_width

  # `getWordsByLines`: the words of `text` as lines. Breaking needs a width; without one the text is one line.
  #
  # @api private
  # @param text [String]
  # @param width [Numeric, nil] the line width the words must fit (nil or 0: no breaking)
  # @return [Array<String>] the lines, never empty
  def lines(text, width: nil)
    words = text.to_s.empty? ? [ "" ] : text.to_s.split(BREAKING_SPACES, -1)
    return [ words.join(" ") ] if width.nil? || width.zero?

    space = @char_width
    broken = words.each_with_object([]) do |word, result|
      size = width(word)
      current = result.last
      if current && current[:width] + size + space < width
        current[:words] << word
        current[:width] += size + space
      else
        result << { words: [ word ], width: size }
      end
    end
    broken.map { |line| line[:words].join(" ") }
  end

  # The `dy` of the first line (`reduceCSSCalc` of recharts' `startDy`): `start` hangs below the point, `end` sits above it, `middle`
  # is centered on it.
  #
  # @api private
  # @param anchor [Symbol] :start, :middle or :end
  # @param count [Integer] number of lines
  # @return [String]
  def first_dy(anchor, count)
    case anchor
    when :start then "0.71em"
    when :middle then "#{Chadcn::Chart::Shape::Number.format(((count - 1) / 2.0 * -1) + (0.71 / 2))}em"
    else "#{Chadcn::Chart::Shape::Number.format((count - 1) * -1.0)}em"
    end
  end
end
