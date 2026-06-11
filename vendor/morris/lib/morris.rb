# frozen_string_literal: true

require_relative "morris/version"
require "helpers/configuration"

# Representative objects we create
require_relative "morris/user"
require_relative "morris/post"

require_relative "morris/scrapers/scraper"
require_relative "morris/scrapers/video_scraper"
require_relative "morris/scrapers/post_scraper"
require_relative "morris/scrapers/user_scraper"

# REST API client used to bypass the browser scraper when an Antena token is configured.
require_relative "morris/antena_client"

module Morris
  extend Configuration

  class Error < StandardError
    def initialize(msg = "Morris encountered an error scraping TikTok")
      super
    end
  end

  class ContentUnavailableError < Error
    attr_reader :additional_data

    def initialize(msg = "Morris could not find content requested", additional_data: {})
      super(msg)
      @additional_data = additional_data
    end

    def to_honeybadger_context
      additional_data
    end
  end

  class AccountNotFoundError < Error
    attr_reader :additional_data

    def initialize(msg = "Morris could not find account requested", additional_data: {})
      super(msg)
      @additional_data = additional_data
    end

    def to_honeybadger_context
      additional_data
    end
  end

  class RetryableError < Error; end

  class MediaRequestTimedOutError < RetryableError
    def initialize(msg = "Morris encountered a timeout error requesting an media")
      super
    end
  end

  class MediaRequestFailedError < RetryableError
    def initialize(msg = "Morris received a non-200 response requesting an media")
      super
    end
  end

  define_setting :temp_storage_location, "tmp/Morris"

  # When set, the browser scraper is bypassed and posts are fetched from the Antena REST API.
  define_setting :antena_token, ENV["ANTENA_TOKEN"]
  define_setting :antena_base_endpoint, ENV["ANTENA_BASE_ENDPOINT"]

  # Get an image from a URL and save to a temp folder set in the configuration under
  # temp_storage_location
  def self.retrieve_media(url)
    response = Typhoeus.get(url)

    # Get the file extension if it's in the file
    stripped_url = url.split("?").first  # remove URL query params
    extension = stripped_url.split(".").last

    # Do some basic checks so we just empty out if there's something weird in the file extension
    # that could do some harm.
    if extension.length.positive?
      extension = nil unless /^[a-zA-Z0-9]+$/.match?(extension)
      extension = ".#{extension}" unless extension.nil?
    end

    temp_file_name = "#{Morris.temp_storage_location}/morris_media_#{SecureRandom.uuid}#{extension}"

    # We do this in case the folder isn't created yet, since it's a temp folder we'll just do so
    self.create_temp_storage_location
    File.binwrite(temp_file_name, response.body)
    temp_file_name
  end

private

  def self.create_temp_storage_location
    return if File.exist?(Morris.temp_storage_location) && File.directory?(Morris.temp_storage_location)
    FileUtils.mkdir_p Morris.temp_storage_location
  end
end
