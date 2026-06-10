# frozen_string_literal: true

module Birdsong
  class Tweet
    def self.lookup(ids = [])
      # If a single id is passed in we make it the appropriate array
      ids = [ids] unless ids.kind_of?(Array)

      # Check that the ids are at least real ids
      ids.each { |id| raise Birdsong::InvalidIdError if !/\A\d+\z/.match(id) }

      tweet_objects = ids.map do |id|
        if Birdsong.antena_token.to_s.empty?
          Birdsong::TweetScraper.new.parse(id)
        else
          # When an Antena token is configured we bypass the browser scraper entirely
          # and fetch the tweet from the Antena REST API instead.
          Birdsong::AntenaClient.new.fetch(id)
        end
      end

      tweet_objects.map do |tweet_object|
        Tweet.new(tweet_object)
      end
    end

    # Attributes for after the response is parsed from Twitter
    attr_reader :json
    attr_reader :id
    attr_reader :created_at
    attr_reader :text
    attr_reader :language
    attr_reader :author_id
    attr_reader :author
    attr_reader :images
    attr_reader :videos
    attr_reader :video_file_type
    attr_reader :video_preview_images
    attr_reader :screenshot_file

    alias_method :user, :author # Every other gem uses `user` so we can just alias it

  private

    def initialize(tweet_object)
      @id = tweet_object[:id]
      @created_at = DateTime.parse(tweet_object[:date])
      @text = tweet_object[:text]
      @language = tweet_object[:language]
      @author_id = tweet_object[:user][:id]
      @images = tweet_object[:images]
      @videos = tweet_object[:videos]
      @video_file_type = tweet_object[:video_file_type]
      @video_preview_images = tweet_object[:video_preview_images]
      @screenshot_file = tweet_object[:screenshot_file]
      # Look up the author given the new id.
      # NOTE: This doesn't *seem* like the right place for this, but I"m not sure where else
      @author = User.new(tweet_object[:user])
    end
  end
end
