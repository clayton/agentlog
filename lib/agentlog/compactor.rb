# frozen_string_literal: true

require "date"
require "json"

module Agentlog
  class Compactor
    def initialize(configuration)
      @configuration = configuration
      @preserve_keys = configuration.preserve_keys.to_set { |key| normalize_key(key) }
    end

    def compact(value, key: nil)
      return compact_scalar(value, key:) unless value.is_a?(Hash) || value.is_a?(Array)

      case value
      when Hash
        compact_hash(value)
      when Array
        compact_array(value, key:)
      end
    end

    private

    attr_reader :configuration

    def compact_hash(hash)
      return "{}" if hash.empty?

      pairs = hash.each_with_object([]) do |(key, value), memo|
        break memo if memo.length >= configuration.max_hash_pairs

        memo << "#{key}:#{compact(value, key: key)}"
      end

      omitted = hash.size - pairs.length
      suffix = omitted.positive? ? ",+#{omitted}" : ""
      "{#{pairs.join(",")}#{suffix}}"
    end

    def compact_array(array, key:)
      return "[]" if array.empty?

      sample_limit = scalar_array?(array) ? [array.length, 3].min : configuration.max_array_samples
      samples = array.first(sample_limit).map { |item| compact(item, key:) }
      suffix = array.length > sample_limit ? " x#{array.length}" : ""
      "[#{samples.join("|")}#{suffix}]"
    end

    def compact_scalar(value, key:)
      return display_scalar(value) if preserve_key?(key)

      case value
      when NilClass
        "nil"
      when TrueClass, FalseClass
        "bool"
      when Integer
        "int"
      when Float
        "float"
      when String
        "str(#{value.length})"
      when Symbol
        "sym"
      when Time, Date, DateTime
        value.class.name.downcase
      else
        compact_unknown(value)
      end
    end

    def compact_unknown(value)
      return compact(value.as_json) if respond_to_json_hash?(value)

      value.class.name.split("::").last.to_s.downcase
    end

    def respond_to_json_hash?(value)
      value.respond_to?(:as_json) && !value.is_a?(Numeric)
    end

    def display_scalar(value)
      case value
      when String
        JSON.generate(truncate(value))
      else
        value.inspect
      end
    end

    def truncate(value)
      return value if value.length <= 40

      "#{value[0, 37]}..."
    end

    def preserve_key?(key)
      return false if key.nil?

      @preserve_keys.include?(normalize_key(key))
    end

    def normalize_key(key)
      key.to_s
    end

    def scalar_array?(array)
      array.all? { |item| !item.is_a?(Hash) && !item.is_a?(Array) }
    end
  end
end
