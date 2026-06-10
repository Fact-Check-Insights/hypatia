# frozen_string_literal: true

require_relative "lib/birdsong/version"

Gem::Specification.new do |spec|
  spec.name          = "birdsong"
  spec.version       = Birdsong::VERSION
  spec.authors       = ["Christopher Guess"]
  spec.email         = ["cguess@gmail.com"]

  spec.summary       = "A gem to interface with Twitter's API V2"
  # spec.description   = "TODO: Write a longer description or delete this line."
  # spec.homepage      = "TODO: Put your gem's website or public repo URL here."
  spec.license       = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.7.0")

  # spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"

  # spec.metadata["homepage_uri"] = spec.homepage
  # spec.metadata["source_code_uri"] = "TODO: Put your gem's public repo URL here."
  # spec.metadata["changelog_uri"] = "TODO: Put your gem's CHANGELOG.md URL here."

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{\A(?:test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Prod dependencies
  spec.add_dependency "typhoeus", "~> 1.4.0"
  spec.add_dependency "oauth", "~> 0.5.6"
  spec.add_dependency "oj", "~> 3.16", ">= 3.16.3"
  spec.add_dependency "capybara", "~> 3.40"
  spec.add_dependency "selenium-webdriver", "~> 4.40", ">= 4.40.0"
  spec.add_dependency "curb", "~> 1.0", ">= 1.0.5"
  spec.add_dependency "rotp"

  # Dev dependencies
  spec.add_development_dependency "debug"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "minitest"
  spec.add_development_dependency "rubocop", "~>1.6"
  spec.add_development_dependency "rubocop-rails"
  spec.add_development_dependency "rubocop-rails_config"
  # spec.add_development_dependency "rubocop-performance"
  spec.add_development_dependency "dotenv"
  spec.add_development_dependency "solargraph"

  # For more information and examples about making a new gem, checkout our
  # guide at: https://bundler.io/guides/creating_gem.html
end
