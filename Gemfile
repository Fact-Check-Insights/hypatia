source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "3.3.6"

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails', branch: 'main'
gem "rails", "~> 7.2"
# Use sqlite3 as the database for Active Record
gem "sqlite3", "~> 1.4"
# Use Puma as the app server
gem "puma", "~> 5.0"
# Use SCSS for stylesheets
gem "sass-rails", ">= 6"
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem "jbuilder", "~> 2.7"
# Use Redis adapter to run Action Cable in production
# gem 'redis', '~> 4.0'
# Use Active Model has_secure_password
# gem 'bcrypt', '~> 3.1.7'

# Use Active Storage variant
# gem 'image_processing', '~> 1.2'

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", ">= 1.4.4", require: false

group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem "byebug", platforms: [:mri, :mingw, :x64_mingw]

  # Discover N+1 statements
  gem "bullet"

  # Jard is an improvement on Byebug
  gem "ruby_jard"
  gem "pry-byebug"

  # RuboCop is an excellent linter, we keep it in `test` for CI
  gem "rubocop", require: false
  gem "rubocop-rails", require: false # Rails specific styles
  gem "rubocop-rails_config", require: false # More Rails stuff
  gem "rubocop-performance", require: false # Performance checks
  gem "rubocop-minitest", require: false # For checking tests
end

group :development do
  # Access an interactive console on exception pages or by calling 'console' anywhere in the code.
  gem "web-console", ">= 4.1.0"
  # Display performance information such as SQL time and flame graphs for each request in your browser.
  # Can be configured to work on production as well see: https://github.com/MiniProfiler/rack-mini-profiler/blob/master/README.md
  gem "rack-mini-profiler", "~> 2.0"
  gem "listen", "~> 3.3"
  # Spring is removed here because it causes serious issues with the scrapers

  # This is required for Ruby 3 from Sorbet
  gem "sorted_set"

  # Tmuxinator lets us set up standard development environments easily
  gem "tmuxinator"

  # Yard is for documenting the code
  gem "yard", require: false

  gem "ruby-lsp"
end

group :test do
  gem "net-ping"
end

# Adds support for Capybara system testing and selenium driver
gem "capybara", ">= 3.26"
gem "selenium-webdriver", ">= 4.32.0"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: [:mingw, :mswin, :x64_mingw, :jruby]

# The whole point of this app
gem "zorki", git: "https://github.com/Fact-Check-Insights/zorki"
# gem "zorki", path: "/Users/christopher/Repositories/zorki"
gem "forki", git: "https://github.com/Fact-Check-Insights/forki", branch: "main"
# gem "forki", "0.2.9", path: "/Users/christopher/Repositories/Reporters_Lab/forki"
gem "youtubearchiver", git: "https://github.com/Fact-Check-Insights/YoutubeArchiver"
# gem "birdsong", path: "/Users/christopher/Repositories/birdsong"
# gem "birdsong", "0.2.7", git: "https://github.com/cguess/birdsong", branch: "selenium-upgrade"
gem "birdsong", git: "https://github.com/Fact-Check-Insights/birdsong", branch: "master"
# gem "mosquito-scrape", git: "https://github.com/TechAndCheck/mosquito", branch: "main", require: "mosquito"
# gem "mosquito-scrape", path: "/Users/christopher/Repositories/mosquito", require: "mosquito"
gem "morris", git: "https://github.com/Fact-Check-Insights/morris", branch: "main"
# gem "morris", path: "/Users/christopher/Repositories/Reporters_Lab/morris"

# Run shell commands (yt-dlp)
gem "terrapin"

# Figaro lets us configure and require environment variable at boot, instead of getting stuck with a
# bad deployment
gem "figaro"

# Add the ability to load `.env` files on launch
gem "dotenv-rails"

# Make JSON-ifying stuff easier
gem "blueprinter" # git: "https://github.com/blueprinter-ruby/blueprinter"

# Used to store settings for auth keys
gem "rails-settings-cached"

# For creating web requests
gem "typhoeus"

# New way to bundle CSS and JS for Rails 7
gem "cssbundling-rails"
gem "importmap-rails"

# Use Stimulus for Rails 7
gem "stimulus-rails"

# Sprockets helps do the CSS stuff
gem "sprockets-rails", require: "sprockets/railtie"

# Tailwind CSS integration
gem "tailwindcss-rails", "~> 2.0"

# New Rails 3.1 debug
gem "debug", ">= 1.0.0"

# Handles the queuing for jobs
gem "sidekiq", "~> 6.5.5"

# AWS for uploading to S3
gem "aws-sdk-s3"

# Curb uses CURL instead of Net::HTTP for capybara
gem "curb", "~> 1.0", ">= 1.0.5"

gem "slack-ruby-client"

gem "honeybadger", "~> 5.2"

gem "localhost"

gem "selenium-devtools"
