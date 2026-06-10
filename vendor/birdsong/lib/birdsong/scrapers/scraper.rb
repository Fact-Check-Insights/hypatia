# frozen_string_literal: true

require "base64"
require "capybara/dsl"
require "dotenv/load"
require "oj"
require "selenium-webdriver"
require "logger"
require "securerandom"
require "selenium/webdriver/remote/http/curb"
# require "debug"

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
options.add_argument("--user-data-dir=/tmp/tarun_zorki_#{SecureRandom.uuid}")
options.logging_prefs = { performance: "ALL" }

Capybara.register_driver :selenium_birdsong do |app|
  client = Selenium::WebDriver::Remote::Http::Curb.new
  # client.read_timeout = 60  # Don't wait 60 seconds to return Net::ReadTimeoutError. We'll retry through Hypatia after 10 seconds
  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options, http_client: client)
end

Capybara.threadsafe = true
Capybara.default_max_wait_time = 60
Capybara.reuse_server = true

module Birdsong
  class Scraper # rubocop:disable Metrics/ClassLength
    include Capybara::DSL

    @@logger = Logger.new(STDOUT)
    @@logger.level = Logger::WARN
    @@logger.datetime_format = "%Y-%m-%d %H:%M:%S"
    @@session_id = nil

    def initialize
      Capybara.default_driver = :selenium_birdsong
    end

    # Instagram uses GraphQL (like most of Facebook I think), and returns an object that actually
    # is used to seed the page. We can just parse this for most things.
    #
    # additional_search_params is a comma seperated keys
    # example: `data,xdt_api__v1__media__shortcode__web_info,items`
    #
    # @returns Hash a ruby hash of the JSON data
    def get_content_of_subpage_from_url(url, subpage_search, additional_search_parameters = nil, &block)
      # Tweet JSON arrives in a later XHR, not the initial HTML. We watch Chrome's
      # performance log for Network.responseReceived entries whose URL matches
      # subpage_search, then read the body via CDP Network.getResponseBody once
      # Network.loadingFinished fires for that request id.
      response_body = nil
      matching_request_urls = {}

      load_saved_cookies
      # Drain anything the login navigation already put in the perf log.
      page.driver.browser.logs.get("performance")

      page.driver.browser.navigate.to(url)

      start_time = Time.now
      sleep(rand(10...20))

      while response_body.nil? && (Time.now - start_time) < 60
        page.driver.browser.logs.get("performance").each do |entry|
          message = parse_perf_log_entry(entry)
          next if message.nil?

          case message["method"]
          when "Network.responseReceived"
            req_url = message.dig("params", "response", "url").to_s
            next unless req_url.include?(subpage_search)
            matching_request_urls[message.dig("params", "requestId")] = req_url
          when "Network.loadingFinished"
            req_id = message.dig("params", "requestId")
            next unless matching_request_urls.key?(req_id)

            body = fetch_cdp_response_body(req_id)
            next if body.nil? || body.empty?

            puts "checking request: #{matching_request_urls[req_id]}"
            puts "for subpage: #{subpage_search}"
            puts "passed"

            check_passed = true
            unless additional_search_parameters.nil?
              puts "checking additional search parameters #{additional_search_parameters}"
              body_to_check = Oj.load(body)

              additional_search_parameters.split(",").each do |key|
                break if body_to_check.nil?

                check_passed = false unless body_to_check.is_a?(Hash) && body_to_check.key?(key)
                body_to_check = body_to_check[key]
              end
            end

            if check_passed && block_given?
              check_passed = begin
                block.call(JSON.parse(body))
              rescue StandardError
                false
              end
            end

            if check_passed
              response_body = body
              break
            end
          end
        end

        sleep(0.1) if response_body.nil?
      end

      page.driver.execute_script("window.stop();")
      save_cookies

      raise Birdsong::NoTweetFoundError if response_body.nil?
      Oj.load(response_body)
    rescue Birdsong::WebDriverError
    end

  private

    # Chrome's performance log entries are JSON strings wrapping a CDP message.
    def parse_perf_log_entry(entry)
      Oj.load(entry.message)["message"]
    rescue StandardError
      nil
    end

    def fetch_cdp_response_body(request_id)
      result = page.driver.browser.execute_cdp("Network.getResponseBody", requestId: request_id)
      body = result["body"]
      return nil if body.nil?
      result["base64Encoded"] ? Base64.decode64(body) : body
    rescue Selenium::WebDriver::Error::WebDriverError
      nil
    end

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
      options.add_argument("--user-data-dir=/tmp/tarun_zorki_#{SecureRandom.uuid}")
      # options.add_argument("--user-data-dir=/tmp/tarun")
      options.logging_prefs = { performance: "ALL" }

      Capybara.register_driver :selenium do |app|
        client = Selenium::WebDriver::Remote::Http::Curb.new
        # client.read_timeout = 60  # Don't wait 60 seconds to return Net::ReadTimeoutError. We'll retry through Hypatia after 10 seconds
        Capybara::Selenium::Driver.new(app, browser: :chrome, options: options, http_client: client)
      end

      Capybara.current_driver = :selenium
    end

    def is_logged_in?(id = nil)
      load_saved_cookies
      # Check if we're on a Twitter page already, if not visit it.
      if id.nil?
        page.driver.browser.navigate.to("https://x.com")
      else
        page.driver.browser.navigate.to("https://x.com/jack/status/#{id}") # We may be logged in already?
      end

      # unless page.driver.browser.current_url.include?("twitter.com") || page.driver.browser.current_url.include?("x.com")
      #   # There seems to be a bug in the Linux ARM64 version of chromedriver where this will properly
      #   # navigate but then timeout, crashing it all up. So instead we check and raise the error when
      #   # that then fails again.
      #   if id.nil?
      #     page.driver.browser.navigate.to("https://x.com")
      #   else
      #     page.driver.browser.navigate.to("https://x.com/jack/status/#{id}") # We may be logged in already?
      #   end
      # end

      # We don't have to login if we already are
      begin
        return true if find_field("Search", wait: 10)
      rescue Capybara::ElementNotFound; end

      false
    end

    def login
      # Reset the sessions so that there's nothing laying around
      page.quit

      # If we already have files, do it
      return if is_logged_in?

      page.driver.browser.find_element(link_text: "Sign in").click      # Check if we're redirected to a login page, if we aren't we're already logged in

      # return unless page.has_xpath?('//*[@id="loginForm"]/div/div[3]/button')

      # Try to log in
      loop_count = 0
      while loop_count < 5 do
        3.times do
          sleep(rand * 8.8)
          element = page.driver.browser.find_element(tag_name: "input", name: "text")
          next if element.nil?
          element.click
          break
        rescue StandardError => e
          puts e
          next
        end

        sleep(rand * 2.8)
        fill_in("text", with: ENV["TWITTER_USER_NAME"])
        sleep(rand * 2.8)
        find_button("Next").click
        sleep(rand * 2.1)
        fill_in("password", with: ENV["TWITTER_PASSWORD"])

        begin
          click_button("Log in", exact_text: true) # Note: "Log in" (lowercase `in`) instead redirects to Facebook's login page
        rescue Capybara::ElementNotFound; end # If we can't find it don't break horribly, just keep waiting

        break unless has_css?('p[data-testid="login-error-message"', wait: 10)
        loop_count += 1
        sleep(rand * 10.3)
      end

      # Sometimes Twitter just... doesn't let you log in
      raise "Twitter not accessible" if loop_count == 5

      # Save the logged in cookies for restoring later
      save_cookies
      # No we don't want to save our login credentials
      begin
        click_on("Save Info")
      rescue Capybara::ElementNotFound; end
    end

    def logout
      page.driver.browser.navigate.to("https://x.com/logout")
      click_button("Log out", exact_text: true)
    end

    def fetch_image(url)
      request = Typhoeus::Request.new(url, followlocation: true)
      request.on_complete do |response|
        if request.success?
          return request.body
        elsif request.timed_out?
          raise Zorki::Error("Fetching image at #{url} timed out")
        else
          raise Zorki::Error("Fetching image at #{url} returned non-successful HTTP server response #{request.code}")
        end
      end
    end

    # Convert a string to an integer
    def number_string_to_integer(number_string)
      # First we have to remove any commas in the number or else it all breaks
      number_string = number_string.delete(",")
      # Is the last digit not a number? If so, we're going to have to multiply it by some multiplier
      should_expand = /[0-9]/.match(number_string[-1, 1]).nil?

      # Get the last index and remove the letter at the end if we should expand
      last_index = should_expand ? number_string.length - 1 : number_string.length
      number = number_string[0, last_index].to_f
      multiplier = 1
      # Determine the multiplier depending on the letter indicated
      case number_string[-1, 1]
      when "m"
        multiplier = 1_000_000
      end

      # Multiply everything and insure we get an integer back
      (number * multiplier).to_i
    end

    def save_cookies
      cookies_json = page.driver.browser.manage.all_cookies.to_json
      File.write("birdsong_cookies.json", cookies_json)
    end

    def load_saved_cookies
      return unless File.exist?("birdsong_cookies.json")
      page.driver.browser.navigate.to("https://x.com")

      cookies_json = File.read("birdsong_cookies.json")
      cookies = JSON.parse(cookies_json, symbolize_names: true)
      cookies.each do |cookie|
        cookie[:expires] = Time.parse(cookie[:expires]) unless cookie[:expires].nil?
        begin
          page.driver.browser.manage.add_cookie(cookie)
        rescue StandardError
        end
      end
    end
  end
end

# require_relative "tweet_scraper"
