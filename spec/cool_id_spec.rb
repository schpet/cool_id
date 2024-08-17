# frozen_string_literal: true

require "active_record"

# frozen_string_literal: true

class User < ActiveRecord::Base
  include CoolId::Model
  register_cool_id prefix: "usr"
end

class CustomUser < ActiveRecord::Base
  include CoolId::Model
  register_cool_id prefix: "cus", alphabet: "ABCDEFGHIJKLMNOPQRSTUVWXYZ", length: 8
end

RSpec.describe CoolId do
  it "has a version number" do
    expect(CoolId::VERSION).not_to be nil
  end

  describe ".generate_id" do
    it "generates an ID with default parameters" do
      config = CoolId::Config.new(prefix: nil)
      id = CoolId.generate_id(config)
      expect(id).to match(/^[0-9a-z]{12}$/)
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

    it "generates an ID without prefix when prefix is nil" do
      config = CoolId::Config.new(prefix: nil, length: 15)
      id = CoolId.generate_id(config)
      expect(id).to match(/^[0-9a-z]{15}$/)
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
      CoolId.separator = "_" # Reset to default
    end

    it "uses the globally configured length" do
      original_length = CoolId.length
      CoolId.configure { |config| config.length = 8 }
      config = CoolId::Config.new(prefix: "test")
      id = CoolId.generate_id(config)
      expect(id).to match(/^test_[0-9a-z]{8}$/)
      CoolId.length = original_length # Reset to default
    end

    it "uses the config length over the global length" do
      original_length = CoolId.length
      CoolId.configure { |config| config.length = 8 }
      config = CoolId::Config.new(prefix: "test", length: 6)
      id = CoolId.generate_id(config)
      expect(id).to match(/^test_[0-9a-z]{6}$/)
      CoolId.length = original_length # Reset to default
    end
  end

  describe CoolId::Model do
    before(:all) do
      ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
    end

    before(:each) do
      ActiveRecord::Schema.define do
        create_table :users, id: false do |t|
          t.string :id, primary_key: true
          t.string :name
        end

        create_table :custom_users, id: false do |t|
          t.string :id, primary_key: true
          t.string :name
        end
      end
    end

    after(:each) do
      ActiveRecord::Base.connection.drop_table :users
      ActiveRecord::Base.connection.drop_table :custom_users
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
      original_separator = CoolId.separator
      CoolId.separator = "-"
      custom_user = CustomUser.create(name: "Alice")
      expect(custom_user.id).to match(/^cus-[A-Z]{8}$/)
      CoolId.separator = original_separator
    end

    it "raises an error when trying to set an empty or whitespace-only prefix" do
      expect {
        Class.new(ActiveRecord::Base) do
          include CoolId::Model
          register_cool_id prefix: ""
        end
      }.to raise_error(ArgumentError, "Prefix cannot consist only of whitespace")

      expect {
        Class.new(ActiveRecord::Base) do
          include CoolId::Model
          register_cool_id prefix: "   "
        end
      }.to raise_error(ArgumentError, "Prefix cannot consist only of whitespace")

      expect {
        Class.new(ActiveRecord::Base) do
          include CoolId::Model
          register_cool_id prefix: nil
        end
      }.not_to raise_error
    end

    it "raises an error when the alphabet includes the separator" do
      original_separator = CoolId.separator
      CoolId.separator = "-"
      expect {
        CoolId::Config.new(prefix: "test", alphabet: "ABC-DEF")
      }.to raise_error(ArgumentError, "Alphabet cannot include the separator '-'")
      CoolId.separator = original_separator
    end

    it "can locate a record using CoolId.locate" do
      user = User.create(name: "John Doe")
      located_user = CoolId.locate(user.id)
      expect(located_user).to eq(user)
    end

    it "can locate a custom record using CoolId.locate" do
      custom_user = CustomUser.create(name: "Alice")
      located_custom_user = CoolId.locate(custom_user.id)
      expect(located_custom_user).to eq(custom_user)
    end

    it "returns nil when trying to locate a non-existent record" do
      expect(CoolId.locate("usr_nonexistent")).to be_nil
    end

    it "returns nil when trying to locate a record with an unknown prefix" do
      expect(CoolId.locate("unknown_prefix_123")).to be_nil
    end

    it "works with different separators" do
      user = User.create(name: "John Doe")
      custom_user = CustomUser.create(name: "Jane Doe")

      expect(CoolId.locate(user.id)).to eq(user)
      expect(CoolId.locate(custom_user.id)).to eq(custom_user)
    end
  end
end
