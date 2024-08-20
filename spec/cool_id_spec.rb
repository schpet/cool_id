# frozen_string_literal: true

# rubocop:disable Lint/ConstantDefinitionInBlock

require "active_record"

class User < ActiveRecord::Base
  include CoolId::Model
  cool_id prefix: "usr"
end

class Customer < ActiveRecord::Base
  include CoolId::Model
  cool_id prefix: "cus", alphabet: "ABCDEFGHIJKLMNOPQRSTUVWXYZ", length: 8
end

RSpec.describe CoolId do
  before(:each) do
    CoolId.reset_configuration
  end

  it "has a version number" do
    expect(CoolId::VERSION).not_to be nil
  end

  describe ".generate_id" do
    it "generates an ID with default parameters" do
      config = CoolId::Config.new(prefix: "X")
      id = CoolId.generate_id(config)
      expect(id).to match(/^X_[0-9a-z]{12}$/)
    end

    it "generates an ID with an empty prefix" do
      config = CoolId::Config.new(prefix: "X")
      id = CoolId.generate_id(config)
      expect(id).to match(/^X_[0-9a-z]{12}$/)
    end

    it "generates an ID with custom prefix and length" do
      config = CoolId::Config.new(prefix: "test", length: 10)
      id = CoolId.generate_id(config)
      expect(id).to match(/^test_[0-9a-z]{10}$/)
    end

    it "generates an ID without prefix when prefix is empty" do
      config = CoolId::Config.new(prefix: "X", length: 15)
      id = CoolId.generate_id(config)
      expect(id).to match(/^X_[0-9a-z]{15}$/)
    end

    it "generates an ID with custom alphabet" do
      config = CoolId::Config.new(prefix: "X", alphabet: "ABCDEFGHIJKLMNOPQRSTUVWXYZ", length: 10)
      id = CoolId.generate_id(config)
      expect(id).to match(/^X_[A-Z]{10}$/)
    end

    it "uses the globally configured separator" do
      CoolId.configure { |config| config.separator = "-" }
      config = CoolId::Config.new(prefix: "test", length: 10)
      id = CoolId.generate_id(config)
      expect(id).to match(/^test-[0-9a-z]{10}$/)
    end

    it "uses the globally configured length" do
      CoolId.configure { |config| config.length = 8 }
      config = CoolId::Config.new(prefix: "test")
      id = CoolId.generate_id(config)
      expect(id).to match(/^test_[0-9a-z]{8}$/)
    end

    it "uses the config length over the global length" do
      CoolId.configure { |config| config.length = 8 }
      config = CoolId::Config.new(prefix: "test", length: 6)
      id = CoolId.generate_id(config)
      expect(id).to match(/^test_[0-9a-z]{6}$/)
    end

    it "resets configuration to default values" do
      CoolId.configure do |config|
        config.separator = "-"
        config.alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        config.length = 8
      end

      CoolId.reset_configuration

      expect(CoolId.separator).to eq(CoolId::DEFAULT_SEPARATOR)
      expect(CoolId.alphabet).to eq(CoolId::DEFAULT_ALPHABET)
      expect(CoolId.length).to eq(CoolId::DEFAULT_LENGTH)
    end
  end

  describe CoolId::Model do
    before(:all) do
      ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
    end

    before(:each) do
      ActiveRecord::Schema.define do
        create_table :users, id: :string do |t|
          t.string :name
        end

        create_table :customers, id: :string do |t|
          t.string :name
        end
      end
    end

    after(:each) do
      ActiveRecord::Base.connection.drop_table :users
      ActiveRecord::Base.connection.drop_table :customers
    end

    after(:all) do
      ActiveRecord::Base.connection.close
    end

    it "generates a cool_id for a new record" do
      user = User.create(name: "John Doe")
      expect(user.id).to match(/^usr_[0-9a-z]{12}$/)
    end

    it "does not overwrite an existing id" do
      user = User.create(id: "custom-id", name: "Jane Doe")
      expect(user.id).to eq("custom-id")
    end

    it "generates a cool_id with custom settings" do
      CoolId.separator = "-"
      customer = Customer.create(name: "Alice")
      expect(customer.id).to match(/^cus-[A-Z]{8}$/)
      CoolId.reset_configuration
    end

    it "raises an error when trying to set an empty prefix" do
      expect {
        Class.new(ActiveRecord::Base) do
          include CoolId::Model
          cool_id prefix: ""
        end
      }.to raise_error(ArgumentError, "Prefix cannot be empty")

      expect {
        Class.new(ActiveRecord::Base) do
          include CoolId::Model
          cool_id prefix: nil
        end
      }.to raise_error(ArgumentError, "Prefix cannot be nil")
    end

    it "allows whitespace-only prefix" do
      expect {
        Class.new(ActiveRecord::Base) do
          include CoolId::Model
          cool_id prefix: "   "
        end
      }.not_to raise_error
    end

    it "raises an error when the alphabet includes the separator" do
      CoolId.separator = "-"
      expect {
        CoolId::Config.new(prefix: "test", alphabet: "ABC-DEF")
      }.to raise_error(ArgumentError, "Alphabet cannot include the separator '-'")
      CoolId.reset_configuration
    end

    it "can locate a record using CoolId.locate" do
      user = User.create(name: "John Doe")
      located_user = CoolId.locate(user.id)
      expect(located_user).to eq(user)
    end

    it "can locate a custom record using CoolId.locate" do
      customer = Customer.create(name: "Alice")
      located_customer = CoolId.locate(customer.id)
      expect(located_customer).to eq(customer)
    end

    it "returns nil when trying to locate a non-existent record" do
      expect(CoolId.locate("usr_nonexistent")).to be_nil
    end

    it "returns nil when trying to locate a record with an unknown prefix" do
      expect(CoolId.locate("unknown_prefix_123")).to be_nil
    end

    it "works with different separators" do
      user = User.create(name: "John Doe")
      customer = Customer.create(name: "Jane Doe")

      expect(CoolId.locate(user.id)).to eq(user)
      expect(CoolId.locate(customer.id)).to eq(customer)
    end
  end

  describe "ensure_cool_id_setup behavior" do
    before(:all) do
      ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
    end

    before(:each) do
      ActiveRecord::Schema.define do
        create_table :base_records, id: false do |t|
          t.string :id, primary_key: true
          t.string :name
        end

        create_table :unconfigured_models, id: false do |t|
          t.string :id, primary_key: true
          t.string :name
        end

        create_table :configured_models, id: false do |t|
          t.string :id, primary_key: true
          t.string :name
        end

        create_table :skipped_models, id: false do |t|
          t.string :id, primary_key: true
          t.string :name
        end

        create_table :inherited_models, id: false do |t|
          t.string :id, primary_key: true
          t.string :name
        end
      end
    end

    after(:each) do
      ActiveRecord::Base.connection.drop_table :base_records
      ActiveRecord::Base.connection.drop_table :unconfigured_models
      ActiveRecord::Base.connection.drop_table :configured_models
      ActiveRecord::Base.connection.drop_table :skipped_models
      ActiveRecord::Base.connection.drop_table :inherited_models
    end

    after(:all) do
      ActiveRecord::Base.connection.close
    end

    it "raises an error when cool_id is not configured in a subclass" do
      class BaseRecord < ActiveRecord::Base
        self.abstract_class = true
        include CoolId::Model
        enforce_cool_id_for_descendants
      end

      expect {
        class UnconfiguredModel < BaseRecord
        end
        UnconfiguredModel.new
      }.to raise_error(CoolId::UnconfiguredError, <<~ERROR.strip)
        CoolId not configured for UnconfiguredModel. Use 'cool_id' to configure or 'skip_enforce_cool_id' to opt out.

        e.g.

        class UnconfiguredModel < ApplicationRecord
          cool_id prefix: "unc"
        end
      ERROR
    end

    it "does not raise an error when cool_id is configured in a subclass" do
      class BaseRecord < ActiveRecord::Base
        self.abstract_class = true
        include CoolId::Model
        enforce_cool_id_for_descendants
      end

      expect {
        class ConfiguredModel < BaseRecord
          cool_id prefix: "cfg"
        end
        ConfiguredModel.new
      }.not_to raise_error
    end

    it "does not raise an error when cool_id setup is skipped" do
      class BaseRecord < ActiveRecord::Base
        self.abstract_class = true
        include CoolId::Model
        enforce_cool_id_for_descendants
      end

      expect {
        class SkippedModel < BaseRecord
          skip_enforce_cool_id
        end
        SkippedModel.new
      }.not_to raise_error
    end
  end
end

# rubocop:enable Lint/ConstantDefinitionInBlock
