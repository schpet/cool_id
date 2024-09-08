# frozen_string_literal: true

require "benchmark"
require "active_record"
require "cool_id"
require "faker"

# Configure ActiveRecord to use PostgreSQL
ActiveRecord::Base.establish_connection(
  adapter: "postgresql",
  host: ENV["PGHOST"] || "localhost",
  username: ENV["PGUSER"] || "postgres",
  password: ENV["PGPASSWORD"] || "postgres",
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

# Models for UUID primary key
class UuidUser < ActiveRecord::Base
  has_one :uuid_profile
end

class UuidProfile < ActiveRecord::Base
  belongs_to :uuid_user
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

  create_table :uuid_users, id: :uuid, default: -> { "gen_random_uuid()" }, force: true do |t|
    t.string :name
  end

  create_table :uuid_profiles, force: true do |t|
    t.uuid :uuid_user_id
    t.string :bio
  end
end

BATCH_SIZE = 1000

# Generate sample data
def generate_sample_data(count)
  total_batches = count / BATCH_SIZE
  (count / BATCH_SIZE).times do |batch|
    puts "Inserting batch #{batch + 1} of #{total_batches}..."

    cool_id_users = BATCH_SIZE.times.map { {id: CoolIdUser.generate_cool_id, name: Faker::Name.name} }
    cool_id_user_ids = CoolIdUser.insert_all!(cool_id_users).rows.flatten
    puts "  Inserted #{BATCH_SIZE} CoolIdUsers"

    cool_id_profiles = cool_id_user_ids.map { |id| {cool_id_user_id: id, bio: Faker::Lorem.paragraph} }
    CoolIdProfile.insert_all!(cool_id_profiles)
    puts "  Inserted #{BATCH_SIZE} CoolIdProfiles"

    big_int_users = BATCH_SIZE.times.map { {name: Faker::Name.name, public_id: BigIntUser.generate_cool_id} }
    big_int_user_ids = BigIntUser.insert_all!(big_int_users).rows.flatten
    puts "  Inserted #{BATCH_SIZE} BigIntUsers"

    big_int_profiles = big_int_user_ids.map { |id| {big_int_user_id: id, bio: Faker::Lorem.paragraph} }
    BigIntProfile.insert_all!(big_int_profiles)
    puts "  Inserted #{BATCH_SIZE} BigIntProfiles"

    uuid_users = BATCH_SIZE.times.map { {name: Faker::Name.name} }
    uuid_user_ids = UuidUser.insert_all!(uuid_users).rows.flatten
    puts "  Inserted #{BATCH_SIZE} UuidUsers"

    uuid_profiles = uuid_user_ids.map { |id| {uuid_user_id: id, bio: Faker::Lorem.paragraph} }
    UuidProfile.insert_all!(uuid_profiles)
    puts "  Inserted #{BATCH_SIZE} UuidProfiles"

    puts "Batch #{batch + 1} complete"
  end
end

# Benchmark queries
def run_benchmark(iterations)
  Benchmark.bm(20) do |x|
    x.report("BigInt Query:") do
      iterations.times do
        BigIntUser.joins(:big_int_profile).where(id: BigIntUser.pluck(:id).sample).first
      end
    end

    x.report("UUID Query:") do
      iterations.times do
        UuidUser.joins(:uuid_profile).where(id: UuidUser.pluck(:id).sample).first
      end
    end

    x.report("CoolId Query:") do
      iterations.times do
        CoolIdUser.joins(:cool_id_profile).where(id: CoolIdUser.pluck(:id).sample).first
      end
    end
  end
end

# Clean up existing data
def clean_up_data
  ActiveRecord::Base.connection.drop_table :cool_id_users, if_exists: true
  ActiveRecord::Base.connection.drop_table :cool_id_profiles, if_exists: true
  ActiveRecord::Base.connection.drop_table :big_int_users, if_exists: true
  ActiveRecord::Base.connection.drop_table :big_int_profiles, if_exists: true
end

# Main execution
clean_up_data

puts "Setting up schema..."
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

puts "Generating sample data..."
generate_sample_data(10_000)

puts "Running VACUUM..."
ActiveRecord::Base.connection.execute("VACUUM ANALYZE")

puts "Running first round of benchmarks..."
run_benchmark(1000)

puts "\nRunning second round of benchmarks..."
run_benchmark(1000)

# Clean up
clean_up_data
