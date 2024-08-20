# frozen_string_literal: true

require_relative "cool_id/version"
require "nanoid"
require "active_support/concern"

module CoolId
  class CoolIdError < StandardError; end

  # defaults based on https://planetscale.com/blog/why-we-chose-nanoids-for-planetscales-api
  DEFAULT_SEPARATOR = "_"
  DEFAULT_ALPHABET = "0123456789abcdefghijklmnopqrstuvwxyz"
  DEFAULT_LENGTH = 12

  Id = Struct.new(:key, :prefix, :id, :model_class)

  class << self
    attr_accessor :separator, :alphabet, :length

    def configure
      yield self
    end

    def reset_configuration
      self.separator = DEFAULT_SEPARATOR
      self.alphabet = DEFAULT_ALPHABET
      self.length = DEFAULT_LENGTH
    end

    def registry
      @prefix_map ||= Registry.new
    end

    def generate_id(config)
      alphabet = config.alphabet || @alphabet
      length = config.length || @length
      id = Nanoid.generate(size: length, alphabet: alphabet)

      "#{config.prefix}#{separator}#{id}"
    end
  end

  self.separator = DEFAULT_SEPARATOR
  self.alphabet = DEFAULT_ALPHABET
  self.length = DEFAULT_LENGTH

  class Registry
    def initialize
      @prefix_map = {}
    end

    def register(prefix, model_class)
      @prefix_map[prefix] = model_class
    end

    def locate(id)
      parsed = parse(id)
      parsed&.model_class&.find_by(id: id)
    end

    def parse(id)
      prefix, key = id.split(CoolId.separator, 2)
      model_class = @prefix_map[prefix]
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
      raise ArgumentError, "Prefix cannot be empty" if value.empty?
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
      attr_accessor :cool_id_config
      attr_accessor :cool_id_setup_required

      def cool_id(options)
        @cool_id_config = Config.new(**options)
        CoolId.registry.register(options[:prefix], self)
      end

      def generate_cool_id
        CoolId.generate_id(@cool_id_config)
      end

      def enforce_cool_id_for_descendants
        @cool_id_setup_required = true
      end

      def skip_enforce_cool_id_for_descendants
        @cool_id_setup_required = false
      end

      def inherited(subclass)
        super
        if @cool_id_setup_required && !subclass.instance_variable_defined?(:@cool_id_setup_required)
          subclass.instance_variable_set(:@cool_id_setup_required, true)
        end
      end
    end

    included do
      before_create :set_cool_id
      after_initialize :ensure_cool_id_configured

      private

      def set_cool_id
        self.id = self.class.generate_cool_id if id.blank?
      end

      def ensure_cool_id_configured
        if self.class.cool_id_setup_required && self.class.cool_id_config.nil?
          raise CoolIdError, "CoolId not configured for #{self.class}. Use 'cool_id' to configure or 'skip_enforce_cool_id_for_descendants' to opt out."
        end
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
