# frozen_string_literal: true

require_relative "cool_id/version"
require "nanoid"
require "active_support/concern"
require "active_record"

module CoolId
  class Error < StandardError; end

  class << self
    attr_accessor :separator

    def configure
      yield self
    end

    def registry
      @registry ||= Registry.new
    end

    def generate_id(config)
      id = Nanoid.generate(size: config.length, alphabet: config.alphabet)
      [config.prefix, id].reject(&:empty?).join(@separator)
    end
  end

  self.separator = "_"

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

    def initialize(prefix: "", length: 12, alphabet: "0123456789abcdefghijklmnopqrstuvwxyz")
      @prefix = prefix
      @length = length
      self.alphabet = alphabet
    end

    def alphabet=(value)
      validate_alphabet(value)
      @alphabet = value
    end

    private

    def validate_alphabet(value)
      if value.include?(CoolId.separator)
        raise ArgumentError, "Alphabet cannot include the separator '#{CoolId.separator}'"
      end
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
        raise ArgumentError, "Prefix cannot be empty" if options[:prefix] && options[:prefix].empty?
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
