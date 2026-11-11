# frozen_string_literal: true

# Reads the re-layout request `chadcn--chart` sends to a container's `relayout_url:` (dev/port/specs/chart.md, "Resize and re-measure").
# {Chadcn::Chart::Container.relayout_options} is the public entry and owns the bounds ({Chadcn::Chart::Container::RELAYOUT_MAX_SIZE},
# {Chadcn::Chart::Container::RELAYOUT_METRIC_BOUNDS}); they are read at call time, so there is no load-order dependency.
#
# @api private
module Chadcn::Chart::Relayout
  # A request parameter is a plain decimal number (no hex, no `Infinity`).
  DECIMAL = /\A\d+(?:\.\d+)?(?:e[+-]?\d+)?\z/i
  private_constant :DECIMAL

  # @param params [#key?, #[], nil] the request parameters
  # @param id [String, Symbol] the container's `id:`
  # @return [Hash{Symbol => Object}] container keywords; `{}` for another chart or no request
  def self.options(params, id:)
    return {} if id.to_s.empty?

    request = parameter(params, :chart)
    return {} unless request && parameter(request, :id).to_s == id.to_s

    width, height = %i[width height].map { |key| bounded_number(parameter(request, key), Chadcn::Chart::Container::RELAYOUT_MAX_SIZE) }
    options = width && height ? { initial_dimension: { width: width, height: height } } : {}
    Chadcn::Chart::Container::RELAYOUT_METRIC_BOUNDS.each_with_object(options) do |(keyword, bound), result|
      metric = bounded_number(parameter(request, keyword), bound)
      result[keyword] = metric if metric
    end
  end

  # @param params [Object] a Hash, `ActionController::Parameters` or anything else (which has no parameters)
  # @param key [Symbol]
  # @return [Object, nil]
  def self.parameter(params, key)
    return unless params.respond_to?(:key?) && params.respond_to?(:[])

    params.key?(key.to_s) ? params[key.to_s] : params[key]
  end

  # @param raw [Object] a request value
  # @param bound [Numeric]
  # @return [Integer, Float, nil] the positive finite number within `bound`, else nil
  def self.bounded_number(raw, bound)
    number = raw.is_a?(String) && DECIMAL.match?(raw) ? Float(raw) : raw
    return unless (number.is_a?(Integer) || number.is_a?(Float)) && number.finite? && number.positive? && number <= bound

    whole = number.to_i
    number == whole ? whole : number
  end
  private_class_method :parameter, :bounded_number
end
