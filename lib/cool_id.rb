# frozen_string_literal: true

require_relative "cool_id/version"
require "nanoid"
require "active_support/concern"

# The CoolId module provides functionality for generating and managing unique identifiers.
module CoolId
  # Error raised when CoolId is not configured for a model.
  class NotConfiguredError < StandardError; end

  # Error raised when the maximum number of retries is exceeded while generating a unique ID.
  class MaxRetriesExceededError < StandardError; end

  # Default separator used in generated IDs.
  DEFAULT_SEPARATOR = "_"

  # Default alphabet used for generating IDs.
  DEFAULT_ALPHABET = "0123456789abcdefghijklmnopqrstuvwxyz"

  # Default length of the generated ID (excluding prefix and separator).
  DEFAULT_LENGTH = 12

  # Default maximum number of retries when generating a unique ID.
  DEFAULT_MAX_RETRIES = 1000

  # Struct representing a parsed CoolId.
  # @attr [String] key The unique part of the ID (excluding prefix and separator).
  # @attr [String] prefix The prefix of the ID.
  # @attr [String] id The full ID (prefix + separator + key).
  # @attr [Class] model_class The ActiveRecord model class associated with this ID.
  # @attr [Symbol] id_field The field in the model used to store the ID.
  Id = Struct.new(:key, :prefix, :id, :model_class, :id_field)

  class << self
    # @!attribute [rw] separator
    #   @return [String] The separator used in generated IDs.
    # @!attribute [rw] alphabet
    #   @return [String] The alphabet used for generating IDs.
    # @!attribute [rw] length
    #   @return [Integer] The length of the generated ID (excluding prefix and separator).
    # @!attribute [rw] max_retries
    #   @return [Integer] The maximum number of retries when generating a unique ID.
    # @!attribute [rw] id_field
    #   @return [Symbol, nil] The default field to use for storing the ID in models.
    attr_accessor :separator, :alphabet, :length, :max_retries, :id_field

    # Configures the CoolId module.
    # @yield [self] Gives itself to the block.
    # @return [void]
    def configure
      yield self
    end

    # Resets the configuration to default values.
    # @return [void]
    def reset_configuration
      self.separator = DEFAULT_SEPARATOR
      self.alphabet = DEFAULT_ALPHABET
      self.length = DEFAULT_LENGTH
      self.max_retries = DEFAULT_MAX_RETRIES
      self.id_field = nil
    end

    # @return [Registry] The default registry that keeps track of which prefixes are associated with which model classes.
    def registry
      @prefix_map ||= Registry.new
    end

    # Generates a unique ID based on the given configuration.
    # @param config [Config] The configuration for ID generation.
    # @param skip_existence_check [Boolean] Whether to skip the existence check (default: false).
    # @return [String] A unique ID.
    # @raise [MaxRetriesExceededError] If unable to generate a unique ID within the maximum number of retries.
    def generate_id(config, skip_existence_check: false)
      alphabet = config.alphabet || @alphabet
      length = config.length || @length
      max_retries = config.max_retries || @max_retries

      retries = 0
      loop do
        nano_id = Nanoid.generate(size: length, alphabet: alphabet)
        full_id = "#{config.prefix}#{separator}#{nano_id}"
        
        if skip_existence_check || !config.model_class.exists?(id: full_id)
          return full_id
        end

        retries += 1
        if retries >= max_retries
          raise MaxRetriesExceededError, "Failed to generate a unique ID after #{max_retries} attempts"
        end
      end
    end

    # Resolves the field (column) to use for storing the CoolId in a model.
    # @param model_class [Class] The ActiveRecord model class.
    # @return [Symbol] The field to use for storing the CoolId.
    def resolve_cool_id_field(model_class)
      model_class.cool_id_config&.id_field || CoolId.id_field || model_class.primary_key
    end
  end

  self.separator = DEFAULT_SEPARATOR
  self.alphabet = DEFAULT_ALPHABET
  self.length = DEFAULT_LENGTH
  self.max_retries = DEFAULT_MAX_RETRIES

  # Registry for managing prefixes and model classes.
  class Registry
    def initialize
      @prefix_map = {}
    end

    # Registers a prefix with a model class.
    # @param prefix [String] The prefix to register.
    # @param model_class [Class] The ActiveRecord model class to associate with the prefix.
    # @return [void]
    def register(prefix, model_class)
      @prefix_map[prefix] = model_class
    end

    # Locates a record by its CoolId.
    # @param id [String] The CoolId to look up.
    # @return [ActiveRecord::Base, nil] The found record, or nil if not found.
    def locate(id)
      parsed = parse(id)
      return nil unless parsed

      id_field = CoolId.resolve_cool_id_field(parsed.model_class)
      parsed.model_class.find_by(id_field => id)
    end

    # Parses a CoolId into its components.
    # @param id [String] The CoolId to parse.
    # @return [Id, nil] The parsed Id object, or nil if parsing fails.
    def parse(id)
      prefix, key = id.split(CoolId.separator, 2)
      model_class = @prefix_map[prefix]
      return nil unless model_class
      id_field = CoolId.resolve_cool_id_field(model_class)
      Id.new(key, prefix, id, model_class, id_field)
    end
  end

  # Configuration class for CoolId generation.
  class Config
    # @return [String] The prefix for generated IDs.
    attr_reader :prefix

    # @return [Integer, nil] The length of the generated ID (excluding prefix and separator).
    attr_reader :length

    # @return [String, nil] The alphabet to use for generating IDs.
    attr_reader :alphabet

    # @return [Integer, nil] The maximum number of retries when generating a unique ID.
    attr_reader :max_retries

    # @return [Class] The ActiveRecord model class associated with this configuration.
    attr_reader :model_class

    # @return [Symbol, nil] The field to use for storing the ID in the model.
    attr_reader :id_field

    # Initializes a new Config instance.
    # @param prefix [String] The prefix for generated IDs.
    # @param model_class [Class] The ActiveRecord model class.
    # @param length [Integer, nil] The length of the generated ID (excluding prefix and separator).
    # @param alphabet [String, nil] The alphabet to use for generating IDs.
    # @param max_retries [Integer, nil] The maximum number of retries when generating a unique ID.
    # @param id_field [Symbol, nil] The field to use for storing the ID in the model.
    def initialize(prefix:, model_class:, length: nil, alphabet: nil, max_retries: nil, id_field: nil)
      @prefix = validate_prefix(prefix)
      @length = length
      @alphabet = validate_alphabet(alphabet)
      @max_retries = max_retries
      @model_class = model_class
      @id_field = id_field
    end

    private

    # Validates the prefix.
    # @param value [String] The prefix to validate.
    # @return [String] The validated prefix.
    # @raise [ArgumentError] If the prefix is nil or empty.
    def validate_prefix(value)
      raise ArgumentError, "Prefix cannot be nil" if value.nil?
      raise ArgumentError, "Prefix cannot be empty" if value.empty?
      value
    end

    # Validates the alphabet.
    # @param value [String, nil] The alphabet to validate.
    # @return [String, nil] The validated alphabet.
    # @raise [ArgumentError] If the alphabet includes the separator.
    def validate_alphabet(value)
      return nil if value.nil?
      raise ArgumentError, "Alphabet cannot include the separator '#{CoolId.separator}'" if value.include?(CoolId.separator)
      value
    end
  end

  # Module to be included in ActiveRecord models for CoolId functionality.
  module Model
    extend ActiveSupport::Concern

    class_methods do
      # @!attribute [rw] cool_id_config
      #   @return [Config] The CoolId configuration for this model.
      # @!attribute [rw] cool_id_setup_required
      #   @return [Boolean] Whether CoolId setup is required for this model.
      attr_accessor :cool_id_config
      attr_accessor :cool_id_setup_required

      # Configures CoolId for this model.
      # @param options [Hash] Options for configuring CoolId.
      # @option options [String] :prefix The prefix for generated IDs.
      # @option options [Integer] :length The length of the generated ID (excluding prefix and separator).
      # @option options [String] :alphabet The alphabet to use for generating IDs.
      # @option options [Integer] :max_retries The maximum number of retries when generating a unique ID.
      # @option options [Symbol] :id_field The field to use for storing the ID in the model.
      # @return [void]
      def cool_id(options)
        @cool_id_config = Config.new(**options, model_class: self)
        CoolId.registry.register(options[:prefix], self)
      end

      # Generates a new CoolId for this model.
      # @param skip_existence_check [Boolean] Whether to skip the existence check (default: false).
      # @return [String] A new CoolId.
      def generate_cool_id(skip_existence_check: false)
        CoolId.generate_id(@cool_id_config, skip_existence_check: skip_existence_check)
      end

      # Enforces CoolId setup for all descendants of this model.
      # @return [void]
      def enforce_cool_id_for_descendants
        @cool_id_setup_required = true
      end

      # Skips enforcing CoolId setup for this model.
      # @return [void]
      def skip_enforce_cool_id
        @cool_id_setup_required = false
      end

      # Inherits CoolId setup requirements to subclasses.
      # @param subclass [Class] The subclass inheriting from this model.
      # @return [void]
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

      # Sets the CoolId for the model instance before creation.
      # @return [void]
      def set_cool_id
        id_field = CoolId.resolve_cool_id_field(self.class)
        self[id_field] = self.class.generate_cool_id if self[id_field].blank?
      end

      # Ensures that CoolId is configured for the model.
      # @raise [NotConfiguredError] If CoolId is not configured and setup is required.
      # @return [void]
      def ensure_cool_id_configured
        if self.class.cool_id_setup_required && self.class.cool_id_config.nil?
          suggested_prefix = self.class.name.downcase[0..2]
          raise NotConfiguredError, "CoolId not configured for #{self.class}. Use 'cool_id' to configure or 'skip_enforce_cool_id' to opt out.\n\ne.g.\n\nclass #{self.class} < ApplicationRecord\n  cool_id prefix: \"#{suggested_prefix}\"\nend"
        end
      end
    end
  end

  # Locates a record by its CoolId.
  # @param id [String] The CoolId to look up.
  # @return [ActiveRecord::Base, nil] The found record, or nil if not found.
  def self.locate(id)
    registry.locate(id)
  end

  # Parses a CoolId into its components.
  # @param id [String] The CoolId to parse.
  # @return [Id, nil] The parsed Id object, or nil if parsing fails.
  def self.parse(id)
    registry.parse(id)
  end
end
