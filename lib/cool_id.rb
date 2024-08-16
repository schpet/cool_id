# frozen_string_literal: true

require_relative "cool_id/version"
require "nanoid"
require "active_support/concern"
require "active_record"

module CoolId
  class Error < StandardError; end

  # defaults copped from
  # https://planetscale.com/blog/why-we-chose-nanoids-for-planetscales-api
  DEFAULT_ALPHABET = "0123456789abcdefghijklmnopqrstuvwxyz"
  DEFAULT_SEPARATOR = "_"
  DEFAULT_LENGTH = 12

  def self.generate_id(prefix: "", separator: DEFAULT_SEPARATOR, length: DEFAULT_LENGTH, alphabet: DEFAULT_ALPHABET)
    id = Nanoid.generate(size: length, alphabet: alphabet)
    [prefix, id].reject(&:empty?).join(separator)
  end

  module Model
    extend ActiveSupport::Concern

    class_methods do
      attr_accessor :cool_id_prefix, :cool_id_separator, :cool_id_alphabet, :cool_id_length

      def generate_cool_id
        CoolId.generate_id(
          prefix: cool_id_prefix,
          separator: cool_id_separator || DEFAULT_SEPARATOR,
          length: cool_id_length || DEFAULT_LENGTH,
          alphabet: cool_id_alphabet || DEFAULT_ALPHABET
        )
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
end
