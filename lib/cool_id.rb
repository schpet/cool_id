# frozen_string_literal: true

require_relative "cool_id/version"
require "nanoid"
require "active_support/concern"
require "active_record"

module CoolId
  class Error < StandardError; end

  class << self
    attr_accessor :separator, :alphabet

    def configure
      yield self
    end

    def registry
      @registry ||= Registry.new
    end

    def generate_id(config)
      alphabet = config.alphabet || @alphabet
      id = Nanoid.generate(size: config.length, alphabet: alphabet)
      [config.prefix, id].compact.reject(&:empty?).join(@separator)
    end
  end

  self.separator = "_"
  self.alphabet = "0123456789abcdefghijklmnopqrstuvwxyz"

  class Registry
    def initialize
      @registry = {}
    end

    def register(prefix, model_class)
      @registry[prefix] = model_class
    end

    def find_model(prefix)
      @registry[prefix]
    end

    def find_record(id)
      prefix, _ = id.split(CoolId.separator, 2)
      model_class = find_model(prefix)
      model_class&.find_by(id: id)
    end
  end

  class Config
    attr_reader :prefix, :length, :alphabet

    def initialize(prefix:, length: 12, alphabet: nil)
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
        raise ArgumentError, "Prefix cannot be empty or consist only of whitespace" if options[:prefix] && options[:prefix].strip.empty?
        @cool_id_config = Config.new(**options)
        CoolId.registry.register(options[:prefix], self)
      end

      def generate_cool_id
        CoolId.generate_id(@cool_id_config || Config.new)
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
    registry.find_record(id)
  end
end
