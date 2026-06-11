# frozen_string_literal: true

module Morris
  class Post
    def self.lookup(urls = [])
      # If a single id is passed in we make it the appropriate array
      urls = [urls] unless urls.kind_of?(Array)
      self.scrape(urls)
    end

    attr_reader :id,
                :text,
                :date,
                :number_of_likes,
                :user,
                :video_file_name,
                :video_preview_image,
                :screenshot_file

  private

    def initialize(post_hash = {})
      @id = post_hash[:id]
      @text = post_hash[:text]
      @date = post_hash[:date]
      @number_of_likes = post_hash[:number_of_likes]
      @user = post_hash[:user]
      @video_file_name = post_hash[:video]
      @video_preview_image = post_hash[:video_preview_image]
      @screenshot_file = post_hash[:screenshot_file]
    end

    class << self
      private

        def scrape(urls)
          urls.map do |url|
            post_hash = if Morris.antena_token.to_s.empty?
                          Morris::PostScraper.new.parse(url)
                        else
                          # When an Antena token is configured we bypass the browser scraper
                          # entirely and fetch the post from the Antena REST API instead.
                          Morris::AntenaClient.new.fetch(url)
                        end
            Post.new(post_hash)
          end
        end
    end
  end
end
