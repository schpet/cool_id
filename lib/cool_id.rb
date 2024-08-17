# frozen_string_literal: true

require_relative "cool_id/version"
require "nanoid"
require "active_support/concern"
require "active_record"

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
      [config.prefix, id].compact.reject(&:empty?).join(@separator)
    end
  end

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
      return nil if value.nil? || value.empty?
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

      def cool_id(options = {})
        register_cool_id(options)
      end

      def register_cool_id(options = {})
        validate_cool_id_options(options)
        @cool_id_config = Config.new(**options)
        CoolId.registry.register(options[:prefix], self)
      end

      private

      def validate_cool_id_options(options)
        if options[:prefix]
          raise ArgumentError, "Prefix cannot be empty or consist only of whitespace" if options[:prefix].strip.empty?
        end
        if options[:length]
          raise ArgumentError, "Length must be a positive integer" unless options[:length].is_a?(Integer) && options[:length] > 0
        end
        if options[:alphabet]
          raise ArgumentError, "Alphabet must be a non-empty string" unless options[:alphabet].is_a?(String) && !options[:alphabet].empty?
          raise ArgumentError, "Alphabet cannot include the separator '#{CoolId.separator}'" if options[:alphabet].include?(CoolId.separator)
        end
      end

      public

      def generate_cool_id
        CoolId.generate_id(@cool_id_config || Config.new(prefix: nil))
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
