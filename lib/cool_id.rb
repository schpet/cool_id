# frozen_string_literal: true

require_relative "cool_id/version"
require "nanoid"
require "active_support/concern"

module CoolId
  class Error < StandardError; end

  Id = Struct.new(:key, :prefix, :id, :model_class)

  class << self
    attr_accessor :separator, :alphabet, :length

    def configure
      yield self
    end

    def registry
      @registry ||= Registry.new
    end

    def generate_id(config)
      alphabet = config.alphabet || @alphabet
      length = config.length || @length
      id = Nanoid.generate(size: length, alphabet: alphabet)

      "#{config.prefix}#{separator}#{id}"
    end
  end

  # defaults based on https://planetscale.com/blog/why-we-chose-nanoids-for-planetscales-api
  self.separator = "_"
  self.alphabet = "0123456789abcdefghijklmnopqrstuvwxyz"
  self.length = 12

  class Registry
    def initialize
      @registry = {}
    end

    def register(prefix, model_class)
      @registry[prefix] = model_class
    end

    def locate(id)
      parsed = parse(id)
      parsed&.model_class&.find_by(id: id)
    end

    def parse(id)
      prefix, key = id.split(CoolId.separator, 2)
      model_class = @registry[prefix]
      return nil unless model_class
      Id.new(key, prefix, id, model_class)
    end
  end

  class Config
    attr_reader :prefix, :length, :alphabet

    def initialize(prefix:, length: nil, alphabet: nil)
      @length = length
      @prefix = validate_prefix(prefix)
      @alphabet = validate_alphabet(alphabet)
    end

    private

    def validate_prefix(value)
      raise ArgumentError, "Prefix cannot be nil" if value.nil?
      raise ArgumentError, "Prefix cannot consist only of whitespace" if value.strip.empty?
      value
    end

    def validate_alphabet(value)
      return nil if value.nil?
      raise ArgumentError, "Alphabet cannot include the separator '#{CoolId.separator}'" if value.include?(CoolId.separator)
      value
    end
  end

  module Model
    extend ActiveSupport::Concern

    class_methods do
      attr_reader :cool_id_config

      def cool_id(options)
        @cool_id_config = Config.new(**options)
        CoolId.registry.register(options[:prefix], self)
      end

      def generate_cool_id
        CoolId.generate_id(@cool_id_config)
      end
    end

    included do
      before_create :set_cool_id

      private

      def set_cool_id
        self.id = self.class.generate_cool_id if id.blank?
      end
    end
  end

  def self.locate(id)
    registry.locate(id)
  end

  def self.parse(id)
    registry.parse(id)
  end
end
