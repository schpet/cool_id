# frozen_string_literal: true

require "benchmark"
require "active_record"
require "cool_id"
require "faker"

# Configure ActiveRecord to use PostgreSQL
ActiveRecord::Base.establish_connection(
  adapter: "postgresql",
  host: "localhost",
  database: "cool_id_benchmark"
)

# Models for cool_id primary key
class CoolIdUser < ActiveRecord::Base
  include CoolId::Model
  cool_id prefix: "usr"
  has_one :cool_id_profile
end

class CoolIdProfile < ActiveRecord::Base
  belongs_to :cool_id_user
end

# Models for bigint primary key with cool_id as public_id
class BigIntUser < ActiveRecord::Base
  include CoolId::Model
  cool_id prefix: "usr", id_field: :public_id
  has_one :big_int_profile
end

class BigIntProfile < ActiveRecord::Base
  belongs_to :big_int_user
end

# Set up database schema
ActiveRecord::Schema.define do
  create_table :cool_id_users, id: :string, force: true do |t|
    t.string :name
  end

  create_table :cool_id_profiles, force: true do |t|
    t.string :cool_id_user_id
    t.string :bio
  end

  create_table :big_int_users, force: true do |t|
    t.string :public_id
    t.string :name
  end

  create_table :big_int_profiles, force: true do |t|
    t.bigint :big_int_user_id
    t.string :bio
  end
end

# Generate sample data
def generate_sample_data(count)
  count.times do
    cool_id_user = CoolIdUser.create!(name: Faker::Name.name)
    CoolIdProfile.create!(cool_id_user: cool_id_user, bio: Faker::Lorem.paragraph)

    big_int_user = BigIntUser.create!(name: Faker::Name.name)
    BigIntProfile.create!(big_int_user: big_int_user, bio: Faker::Lorem.paragraph)
  end
end

# Benchmark queries
def run_benchmark(iterations)
  Benchmark.bm(20) do |x|
    x.report("CoolId Query:") do
      iterations.times do
        CoolIdUser.joins(:cool_id_profile).where(id: CoolIdUser.pluck(:id).sample).first
      end
    end

    x.report("BigInt Query:") do
      iterations.times do
        BigIntUser.joins(:big_int_profile).where(id: BigIntUser.pluck(:id).sample).first
      end
    end
  end
end

# Main execution
puts "Generating sample data..."
generate_sample_data(1_000_000)

puts "Running benchmark..."
run_benchmark(1000)

# Clean up
ActiveRecord::Base.connection.drop_table :cool_id_users
ActiveRecord::Base.connection.drop_table :cool_id_profiles
ActiveRecord::Base.connection.drop_table :big_int_users
ActiveRecord::Base.connection.drop_table :big_int_profiles
