# frozen_string_literal: true

require "typhoeus"
require_relative "scraper"
require "debug"

module Birdsong
  class TweetScraper < Scraper
    def parse(id)
      # Stuff we need to get from the DOM (implemented is starred):
      # - User *
      # - Text *
      # - Image * / Images * / Video *
      # - Date *
      # - Number of likes *
      # - Hashtags

      Capybara.app_host = "https://x.com"

      # video slideshows https://www.instagram.com/p/CY7KxwYOFBS/?utm_source=ig_embed&utm_campaign=loading
      # login

      if is_logged_in?(id)
        graphql_object = get_logged_in_content_of_subpage_for_id(id)
      else
        # If we're logged out we'll try a few paths
        graphql_object = get_logged_out_content_of_subpage_for_id(id)
        if graphql_object.nil? || graphql_object.key?("__typename") && graphql_object["__typename"] == "TweetUnavailable"
          # If the tweet is unavailable, we need to login to access it
          login
          @@logger.info "Logged in, retrying post..."
          graphql_object = get_logged_in_content_of_subpage_for_id(id)
        end
      end

      raise Birdsong::NoTweetFoundError if graphql_object.nil?

      # Certain types of tweets are wrapped in a "tweet" object
      graphql_object = graphql_object["tweet"] if graphql_object.key?("tweet")

      text = graphql_object["legacy"]["full_text"]
      date = graphql_object["legacy"]["created_at"]
      id   = graphql_object["legacy"]["id_str"]
      number_of_likes = graphql_object["legacy"]["favorite_count"]
      language = graphql_object["legacy"]["lang"]

      images = []
      videos = []
      video_preview_images = []
      video_file_type = nil

      if graphql_object["legacy"]["entities"].key?("media")
        graphql_object["legacy"]["entities"]["media"].each do |media|
          case media["type"]
          when "photo"
            images << Birdsong.retrieve_media(media["media_url_https"])
          when "video"
            video_preview_images << Birdsong.retrieve_media(media["media_url_https"])
            video_variants = media["video_info"]["variants"]
            largest_bitrate_variant = video_variants.sort_by do |variant|
              variant.has_key?("bitrate") ? variant["bitrate"] : 0
            end.last

            videos << Birdsong.retrieve_media(largest_bitrate_variant["url"])
            video_file_type = "video"
          when "animated_gif"
            video_preview_images << Birdsong.retrieve_media(media["media_url_https"])
            videos << Birdsong.retrieve_media(media["video_info"]["variants"].first["url"])
            video_file_type = "animated_gif"
          end
        end
      end

      screenshot_file = take_screenshot()

      # This has to run last since it switches pages
      user_object = graphql_object["core"]["user_results"]["result"]
      profile_image_url = user_object["legacy"]["profile_image_url_https"] || user_object["avatar"]["image_url"]
      user = {
        id: user_object["id"],
        name: user_object["core"]["name"],
        username: user_object["core"]["screen_name"],
        sign_up_date: user_object["core"]["created_at"],
        location: user_object["location"]["location"],
        profile_image_url: profile_image_url,
        description: user_object["legacy"]["description"],
        followers_count: user_object["legacy"]["followers_count"],
        following_count: user_object["legacy"]["friends_count"],
        tweet_count: user_object["legacy"]["statuses_count"],
        listed_count: user_object["legacy"]["listed_count"],
        verified: user_object["verification"]["verified"],
        url: user_object["legacy"]["url"],
        profile_image_file_name: Birdsong.retrieve_media(profile_image_url)
      }

      {
        images: images,
        videos: videos,
        video_preview_images: video_preview_images,
        screenshot_file: screenshot_file,
        text: text,
        date: date,
        number_of_likes: number_of_likes,
        user: user,
        id: id,
        language: language,
        video_file_type: video_file_type,
        screenshot_file: screenshot_file
      }
    ensure
      begin
        page.quit
      rescue StandardError => e
        @@logger.warn("Error quitting tweet scraper page: #{e}")
      end
    end

    def get_logged_out_content_of_subpage_for_id(id)
      graphql_object = get_content_of_subpage_from_url(
        "https://x.com/jack/status/#{id}",
        "/TweetResultByRestId",
        "data,tweetResult,result"
      )

      graphql_object = graphql_object.first if graphql_object.kind_of?(Array)
      graphql_object = graphql_object["data"]["tweetResult"]["result"]

      graphql_object
    rescue Birdsong::NoTweetFoundError
      nil
    end

    def get_logged_in_content_of_subpage_for_id(id)
      graphql_object = get_content_of_subpage_from_url("https://x.com/jack/status/#{id}", "/TweetDetail") do |response_body|
        response_body["data"]["threaded_conversation_with_injections_v2"]["instructions"][1]["entries"][0]["content"]["itemContent"]["tweet_results"]["result"]

        true
      rescue StandardError
        false
      end


      # The format gets weird for this request
      graphql_object["data"]["threaded_conversation_with_injections_v2"]["instructions"][1]["entries"][0]["content"]["itemContent"]["tweet_results"]["result"]
    rescue Birdsong::NoTweetFoundError
      nil
    end

    def take_screenshot
      # First check if a post has a fact check overlay, if so, clear it.
      # The only issue is that this can take *awhile* to search. Not sure what to do about that
      # since it's Instagram's fault for having such a fucked up obfuscated hierarchy      # Take the screenshot and return it
      # rubocop:disable Lint/Debugger
      save_screenshot("#{Birdsong.temp_storage_location}/twitter_screenshot_#{SecureRandom.uuid}.png")
      # rubocop:enable Lint/Debugger
    end
  end
end
