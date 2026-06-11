# frozen_string_literal: true

require "capybara/dsl"
require "dotenv/load"
require "oj"
require "selenium-webdriver"
require "logger"
require "securerandom"
require "selenium/webdriver/remote/http/curb"
require "debug"

# 2022-06-07 14:15:23 WARN Selenium [DEPRECATION] [:browser_options] :options as a parameter for driver initialization is deprecated. Use :capabilities with an Array of value capabilities/options if necessary instead.

options = Selenium::WebDriver::Options.chrome(exclude_switches: ["enable-automation"])
options.add_argument("--start-maximized")
options.add_argument("--no-sandbox")
options.add_argument("--disable-dev-shm-usage")
options.add_argument("–-disable-blink-features=AutomationControlled")
options.add_argument("--disable-extensions")
options.add_argument("--enable-features=NetworkService,NetworkServiceInProcess")
options.add_argument("user-agent=Mozilla/5.0 (Macintosh; Intel Mac OS X 13_3_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/113.0.0.0 Safari/537.36")
options.add_preference "password_manager_enabled", false
options.add_argument("--user-data-dir=/tmp/tarun_morris_#{SecureRandom.uuid}")
options.add_argument("--mute-audio")

Capybara.register_driver :selenium_morris do |app|
  client = Selenium::WebDriver::Remote::Http::Curb.new
  # client.read_timeout = 60  # Don't wait 60 seconds to return Net::ReadTimeoutError. We'll retry through Hypatia after 10 seconds
  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options, http_client: client)
end

Capybara.threadsafe = true
Capybara.default_max_wait_time = 60
Capybara.reuse_server = true

module Morris
  class Scraper # rubocop:disable Metrics/ClassLength
    include Capybara::DSL

    @@logger = Logger.new(STDOUT)
    @@logger.level = Logger::WARN
    @@logger.datetime_format = "%Y-%m-%d %H:%M:%S"
    @@session_id = nil

    def initialize
      Capybara.default_driver = :selenium_morris
    end

  private

    ##########
    # Set the session to use a new user folder in the options!
    # #####################
    def reset_selenium
      options = Selenium::WebDriver::Options.chrome(exclude_switches: ["enable-automation"])
      options.add_argument("--start-maximized")
      options.add_argument("--no-sandbox")
      options.add_argument("--disable-dev-shm-usage")
      options.add_argument("–-disable-blink-features=AutomationControlled")
      options.add_argument("--disable-extensions")
      options.add_argument("--enable-features=NetworkService,NetworkServiceInProcess")

      options.add_argument("user-agent=Mozilla/5.0 (Macintosh; Intel Mac OS X 13_3_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/113.0.0.0 Safari/537.36")
      options.add_preference "password_manager_enabled", false
      options.add_argument("--user-data-dir=/tmp/tarun_morris_#{SecureRandom.uuid}")
      # options.add_argument("--user-data-dir=/tmp/tarun")

      Capybara.register_driver :selenium do |app|
        client = Selenium::WebDriver::Remote::Http::Curb.new
        # client.read_timeout = 60  # Don't wait 60 seconds to return Net::ReadTimeoutError. We'll retry through Hypatia after 10 seconds
        Capybara::Selenium::Driver.new(app, browser: :chrome, options: options, http_client: client)
      end

      Capybara.current_driver = :selenium
    end
  end
end
