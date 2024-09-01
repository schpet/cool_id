# frozen_string_literal: true

require_relative "lib/cool_id/version"

Gem::Specification.new do |spec|
  spec.name = "cool_id"
  spec.version = CoolId::VERSION
  spec.authors = ["Peter Schilling"]
  spec.email = ["git@schpet.com"]

  spec.summary = "Generates cool ids for ActiveRecord models"
  spec.description = "CoolId generates primary keys using prefixed nanoids for ActiveRecord models, providing unique and readable identifiers."
  spec.homepage = "https://github.com/schpet/cool_id"
  spec.license = "ISC"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/schpet/cool_id"
  spec.metadata["changelog_uri"] = "https://github.com/schpet/cool_id/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.glob(%w[lib/**/*.rb *.md LICENSE .yardopts])
  spec.require_paths = ["lib"]

  spec.add_dependency "nanoid", "~> 2.0"
  spec.add_dependency "activerecord", ">= 6.0"
  spec.add_dependency "activesupport", ">= 6.0"

  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "standard", "~> 1.3"
  spec.add_development_dependency "yard", "~> 0.9.28"
  spec.add_development_dependency "webrick"
  spec.add_development_dependency "sqlite3", "~> 1.4"
end
