require "capybara/dsl"
class MediaSource
  include Capybara::DSL
  include SlackMessaging

  @@logger = Logger.new(STDOUT)
  @@logger.level = Logger::DEBUG
  @@logger.datetime_format = "%Y-%m-%d %H:%M:%S"

  # Enqueue a job to scrape a URL depending on the site this is set for.
  #
  # @!scope class
  # @param url [String] the url to be scraped
  # @returns [ScrapeJob] the job fired off when this is run
  def self.scrape(url, callback_id = nil, force: false)
    # We want to fail early if the URL is wrong
    CommsManager.send_scrape_status_update(ENV["VM_NAME"], 200, { url: url, scrape_id: callback_id })

    model = self.model_for_url(url)
    raise MediaSource::HostError.new(url) if model.nil?


    if Figaro.env.ALLOW_FORCE == "true" && force == "true"
      self.scrape!(url, callback_id)
    else
      ScrapeJob.perform_later(url, callback_id)
    end
  end

  # Scrape a URL depending on the site this is set for.
  #
  # @!scope class
  # @param url [String] the url to be scraped
  # @returns [Object] the scraped object returned from the respective gem.
  def self.scrape!(url, callback_id)
    CommsManager.send_scrape_status_update(ENV["VM_NAME"], 201, { url: url, scrape_id: callback_id })

    scrape = Scrape.create!({
      url: url,
      callback_id: callback_id,
    })

    model = self.model_for_url(url)
    object = model.extract(scrape)

    object
  rescue Selenium::WebDriver::Error::UnknownError; end


  # Takes a screenshot of the page at +url+ and returns the filepath to the image
  # Waits to take screenshot until the element denoted by +indicator_element_id+ has loaded
  # @param url [String]
  # @param indicator_element_id [String] The id of of an element Capybara should wait on to load before screenshotting
  # @return [String] filepath to the screenshot
  def self.take_screenshot(url = @url, indicator_element_id = nil, wait_time = 10)
    Capybara.default_driver = :hypatia

    session = Capybara::Session.new(:hypatia)
    screenshot_path = nil

    begin
      session.using_wait_time(10) do
        session.driver.browser.navigate.to(url)

        begin
          unless indicator_element_id.nil?
            session.find_by_id(indicator_element_id, wait: wait_time) # Block until page content loads
          else
            sleep(wait_time)
          end
        rescue Capybara::ElementNotFound; end

        media_source_name = self.to_s.delete_suffix("MediaSource").downcase
        save_path = File.join(Rails.root, "tmp", "#{media_source_name}_screenshot_#{SecureRandom.uuid}.png")
        screenshot_path = session.save_screenshot(save_path)
      end
    ensure
      begin
        session.quit
      rescue StandardError => e
        @@logger.warn("Error quitting screenshot session: #{e}")
      end
    end

    screenshot_path
  end

  def self.create_aws_key_functions_for_posts(posts)
    posts.each do |post|
      # First, we add two functions to whatever class the result is.
      # These are implementation details, so we don't want to add them to Zorki or Forki
      # These will allow us to save the AWS keys for later
      #
      # TODO: So I don't have to fix everything we're doubling up here
      post.instance_variable_set("@aws_image_keys", nil)
      post.instance_variable_set("@aws_video_keys", nil)
      post.instance_variable_set("@aws_video_key", nil)
      post.instance_variable_set("@aws_video_preview_keys", nil)
      post.instance_variable_set("@aws_video_preview_key", nil)
      post.instance_variable_set("@aws_screenshot_key", nil)

      post.define_singleton_method(:aws_image_keys) do
        instance_variable_get("@aws_image_keys")
      end

      post.define_singleton_method(:aws_video_keys) do
        instance_variable_get("@aws_video_keys")
      end
      post.define_singleton_method(:aws_video_key) do
        instance_variable_get("@aws_video_key")
      end

      post.define_singleton_method(:aws_video_preview_keys) do
        instance_variable_get("@aws_video_preview_keys")
      end
      post.define_singleton_method(:aws_video_preview_key) do
        instance_variable_get("@aws_video_preview_key")
      end

      post.define_singleton_method(:aws_screenshot_key) do
        instance_variable_get("@aws_screenshot_key")
      end

      self.create_aws_key_functions_for_users(post.user)

      post
    end
  end

  # Add AWS key instance variable getters to a User object
  # Modifies the initial object.
  #
  # @param url A user objects constructed by one of the scraper gems
  # @return nil
  def self.create_aws_key_functions_for_users(user)
    return if user.nil?

    user.instance_variable_set("@aws_profile_image_key", nil)

    user.define_singleton_method(:aws_profile_image_key) do
      instance_variable_get("@aws_profile_image_key")
    end
  end

  # Check if +url+ has a host name the same as indicated by the +@@valid_host+ variable in a
  #   subclass.
  #
  # @!scope class
  # @param url [String] the url to be checked for validity
  # @return [Boolean] if the url is valid given the set @@valid_host.
  #   Raises an error if it's invalid.
  def self.check_url(url)
    # Make sure there's no white space at the end of the URL'
    url.strip!

    raise "This should only be called from a subclass that implements `valid_host_name`" if self == MediaSource

    return true if self.valid_host_name.include?(URI(url).host)
    raise MediaSource::HostError.new(url)
  end

  # A error to indicate the host of a given url does not pass validation
  class HostError < StandardError
    attr_reader :url

    HOST_ERROR_CODE = 10

    def initialize(url)
      @url = url

      super("No valid scraper found for the url #{url}")
    end

    def to_response_structure
      { code: HOST_ERROR_CODE, error: self.message }
    end
  end

  def self.model_for_url(url)
    # Load all models so we can inspect them
    Zeitwerk::Loader.eager_load_all

    # Get all models conforming to ApplicationRecord, and then check if they implement the magic
    # function.
    models = MediaSource.descendants.select do |model|
      if model.respond_to? :can_handle_url?
        model.can_handle_url?(url)
      end
    end

    # We'll always choose the first one
    models.first
  end

  def s3_transfer_enabled?
    Figaro.env.AWS_REGION.present?
  end
end
