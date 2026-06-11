# frozen_string_literal: true

require_relative "lib/morris/version"

Gem::Specification.new do |spec|
  spec.name = "morris"
  spec.version = Morris::VERSION
  spec.authors = ["Christopher Guess"]
  spec.email = ["cguess@gmail.com"]

  spec.summary = "A TikTok media and post scraper"
  spec.description = "The Thing"
  spec.homepage = "https://www.github.com/techandcheck/morris"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  # spec.metadata["allowed_push_host"] = "TODO: Set to your gem server 'https://example.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://www.github.com/techandcheck/morris"
  spec.metadata["changelog_uri"] = "https://www.github.com/techandcheck/morris/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) || f.start_with?(*%w[bin/ test/ spec/ features/ .git .circleci appveyor])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "capybara" # For scraping and running browsers
  spec.add_dependency "apparition" # A Chrome driver for Capybara
  spec.add_dependency "typhoeus" # For making API requests
  spec.add_dependency "oj" # A faster JSON parser/loader than stdlib
  spec.add_dependency "selenium-webdriver" # Webdriver selenium
  spec.add_dependency "selenium-devtools" # Allow us to intercept requests
  spec.add_dependency "terrapin" # For running shell commands

  spec.add_development_dependency "debug"
end
