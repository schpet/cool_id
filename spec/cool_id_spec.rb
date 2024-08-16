# frozen_string_literal: true

require "active_record"

# frozen_string_literal: true

class User < ActiveRecord::Base
  include CoolId::Model
  self.cool_id_prefix = "usr"
end

class CustomUser < ActiveRecord::Base
  include CoolId::Model
  self.cool_id_prefix = "cus"
  self.cool_id_separator = "-"
  self.cool_id_alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
  self.cool_id_length = 8
end

RSpec.describe CoolId do
  it "has a version number" do
    expect(CoolId::VERSION).not_to be nil
  end

  describe ".generate_id" do
    it "generates an ID with default parameters" do
      id = CoolId.generate_id
      expect(id).to match(/^[0-9a-z]{12}$/)
    end

    it "generates an ID with custom prefix, separator, and length" do
      id = CoolId.generate_id(prefix: "test", separator: "-", length: 10)
      expect(id).to match(/^test-[0-9a-z]{10}$/)
    end

    it "generates an ID without prefix when prefix is empty" do
      id = CoolId.generate_id(prefix: "", length: 15)
      expect(id).to match(/^[0-9a-z]{15}$/)
    end

    it "generates an ID with custom alphabet" do
      id = CoolId.generate_id(alphabet: "ABCDEFGHIJKLMNOPQRSTUVWXYZ", length: 10)
      expect(id).to match(/^[A-Z]{10}$/)
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
      custom_user = CustomUser.create(name: "Alice")
      expect(custom_user.id).to match(/^cus-[A-Z]{8}$/)
    end
  end
end
