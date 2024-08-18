# frozen_string_literal: true

require_relative "lib/cool_id/version"

Gem::Specification.new do |spec|
  spec.name = "cool_id"
  spec.version = CoolId::VERSION
  spec.authors = ["Peter Schilling"]
  spec.email = ["git@schpet.com"]

  spec.summary = "generates cool ids"
  spec.description = "generates primary keys using prefixed nanoids for ActiveRecord models"
  spec.homepage = "https://github.com/schpet/cool_id"
  spec.license = "ISC"
  spec.required_ruby_version = ">= 3.0.0"

  # spec.metadata["allowed_push_host"] = "TODO: Set to your gem server 'https://example.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/schpet/cool_id"
  spec.metadata["changelog_uri"] = "https://github.com/schpet/cool_id/tree/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "nanoid", "~> 2.0"
  spec.add_dependency "activerecord", ">= 6.0"
  spec.add_dependency "activesupport", ">= 6.0"

  spec.add_development_dependency "sqlite3", "~> 1.4"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
