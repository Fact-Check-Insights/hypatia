# frozen_string_literal: true

require "securerandom"
require "logger"
require "byebug"
require "terrapin"

module Morris
  class VideoScraper

    class VideoDownloadError < StandardError
      def initialize(msg = "Morris encountered an error scraping TikTok")
        super
      end
    end

    @@morris_logger = Logger.new(STDOUT)
    @@morris_logger.level = Logger::INFO
    @@morris_logger.datetime_format = "%Y-%m-%d %H:%M:%S"

    def self.lookup(url)
      @@morris_logger.debug("Morris started downloading video with id: #{@id}")

      start_time = Time.now
      filename = "#{Morris.temp_storage_location}/morris_media_#{SecureRandom.uuid}.mp4"
      # line = Terrapin::CommandLine.new("yt-dlp", "-f :filetype -o :filename :url")
      line = Terrapin::CommandLine.new("yt-dlp", "-f ':filetype' -o :filename :url")

      line.run(filename: filename,
               filetype: "mp4",
               url: url)

      @@morris_logger.debug("YoutubeArchiver finished downloading video with id: #{@id}")
      @@morris_logger.debug("Save location: #{filename}")
      @@morris_logger.debug("Time to download: #{(Time.now - start_time).round(3)} seconds")

      filename
    rescue Terrapin::ExitStatusError => e # yt-dlp command returns a non-zero exit status
      raise VideoDownloadError.new(e.message) # Retryable error
    end

  #   def self.retrieve_data(ids)
  #     api_key = ENV["YOUTUBE_API_KEY"]
  #     youtube_base_url = "https://youtube.googleapis.com/youtube/v3/videos/"
  #     params = {
  #       "part": "contentDetails,snippet,statistics,status",
  #       "id": ids.join(","),
  #       "key": api_key
  #     }

  #     response = video_lookup(youtube_base_url, params)

  #     response
  #   end

  #   def self.video_lookup(url, params)
  #     options = {
  #       method: "get",
  #       params:
  #     }

  #     request = Typhoeus::Request.new(url, options)
  #     response = request.run

  #     raise YoutubeArchiver::YoutubeApiError, "Invalid response code #{response.code}" if response.code > 500 # Retryable (downstream) error
  #     raise YoutubeArchiver::AuthorizationError, "Invalid response code #{response.code}" if response.code > 400

  #     response
  #   end

  #   # Convert a YouTube duration string to number of seconds
  #   # A duration string of "PT0H4M32S" signifies a length of 4 minutes and 32 seconds
  #   def self.convert_video_length_to_seconds(duration_string)
  #     if /PT((\d+)H)?((\d+)M)?((\d+)S)?/ =~ duration_string  # Use regex to capture num_hours, num_minutes, num_seconds
  #       $2.to_i * 3600 + $4.to_i * 60 + $6.to_i # To convert to seconds, sum(num_hours*3600, num_minutes*60, num_seconds*1)
  #     else
  #       0
  #     end
  #   end
  end
end
