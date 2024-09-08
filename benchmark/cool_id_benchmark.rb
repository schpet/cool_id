# frozen_string_literal: true

require "benchmark"
require "active_record"
require_relative "../lib/cool_id"
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
  ActiveRecord::Base.transaction do
    (count / BATCH_SIZE).times do |batch|
      puts "Preparing batch #{batch + 1} of #{total_batches}..."

      cool_id_users = BATCH_SIZE.times.map { {id: CoolIdUser.generate_cool_id(skip_existence_check: true), name: Faker::Name.name} }
      big_int_users = BATCH_SIZE.times.map { {name: Faker::Name.name, public_id: BigIntUser.generate_cool_id(skip_existence_check: true)} }
      uuid_users = BATCH_SIZE.times.map { {name: Faker::Name.name} }

      cool_id_user_ids = CoolIdUser.insert_all!(cool_id_users).rows.flatten
      big_int_user_ids = BigIntUser.insert_all!(big_int_users).rows.flatten
      uuid_user_ids = UuidUser.insert_all!(uuid_users).rows.flatten

      cool_id_profiles = cool_id_user_ids.map { |id| {cool_id_user_id: id, bio: Faker::Lorem.paragraph} }
      big_int_profiles = big_int_user_ids.map { |id| {big_int_user_id: id, bio: Faker::Lorem.paragraph} }
      uuid_profiles = uuid_user_ids.map { |id| {uuid_user_id: id, bio: Faker::Lorem.paragraph} }

      CoolIdProfile.insert_all!(cool_id_profiles)
      BigIntProfile.insert_all!(big_int_profiles)
      UuidProfile.insert_all!(uuid_profiles)
    end
  end
end

# Prepare sample IDs for benchmarking
def prepare_sample_ids(count)
  {
    big_int: BigIntUser.pluck(:id).sample(count),
    uuid: UuidUser.pluck(:id).sample(count),
    cool_id: CoolIdUser.pluck(:id).sample(count)
  }.transform_values { |ids| ids.compact }
end

# Benchmark queries
def run_benchmark(iterations, sample_ids)
  Benchmark.bm(20) do |x|
    [:big_int, :uuid, :cool_id].each do |id_type|
      x.report("#{id_type.to_s.capitalize} Query:") do
        if sample_ids[id_type].empty?
          puts "No sample IDs for #{id_type}. Skipping benchmark."
        else
          iterations.times do |i|
            case id_type
            when :big_int
              BigIntUser.joins(:big_int_profile).where(id: sample_ids[id_type].sample).first
            when :uuid
              UuidUser.joins(:uuid_profile).where(id: sample_ids[id_type].sample).first
            when :cool_id
              CoolIdUser.joins(:cool_id_profile).where(id: sample_ids[id_type].sample).first
            end
          end
        end
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
  ActiveRecord::Base.connection.drop_table :uuid_users, if_exists: true
  ActiveRecord::Base.connection.drop_table :uuid_profiles, if_exists: true
end

# Parse command-line arguments for sample data size and iterations
sample_size = ARGV[0] ? ARGV[0].to_i : 10_000
iterations = ARGV[1] ? ARGV[1].to_i : [10_000, sample_size].min

# Ensure iterations is not larger than sample size and at least 1
iterations = iterations.clamp(1, sample_size)

# Main execution
clean_up_data

puts "Setting up schema..."
ActiveRecord::Schema.define do
  create_table :cool_id_users, id: :string, force: true do |t|
    t.string :name
    t.index :id, unique: true
  end

  create_table :cool_id_profiles, force: true do |t|
    t.string :cool_id_user_id
    t.string :bio
    t.index :cool_id_user_id
  end

  create_table :big_int_users, force: true do |t|
    t.string :public_id
    t.string :name
    t.index :public_id, unique: true
  end

  create_table :big_int_profiles, force: true do |t|
    t.bigint :big_int_user_id
    t.string :bio
    t.index :big_int_user_id
  end

  create_table :uuid_users, id: :uuid, default: -> { "gen_random_uuid()" }, force: true do |t|
    t.string :name
    t.index :id, unique: true
  end

  create_table :uuid_profiles, force: true do |t|
    t.uuid :uuid_user_id
    t.string :bio
    t.index :uuid_user_id
  end
end

puts "Generating sample data (#{sample_size} records)..."
generate_sample_data(sample_size)

puts "Running VACUUM..."
ActiveRecord::Base.connection.execute("VACUUM ANALYZE")

puts "Preparing sample IDs for benchmarks..."
sample_ids = prepare_sample_ids(10_000)

puts "Running benchmarks..."
run_benchmark(iterations, sample_ids)

# Clean up
clean_up_data
