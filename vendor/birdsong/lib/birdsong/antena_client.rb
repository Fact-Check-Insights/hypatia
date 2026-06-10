# frozen_string_literal: true

require "json"
require "typhoeus"

module Birdsong
  # Client for the Antena REST API. When `ANTENA_TOKEN` is present this replaces the
  # browser-based scraping with a call to Antena, returning the exact same tweet hash
  # schema that `TweetScraper#parse` produces so that `Tweet`/`User` consume it unchanged.
  class AntenaClient
    # How often to poll the job endpoint, in seconds.
    POLL_INTERVAL = 30

    # Maximum number of polls before giving up (~10 minutes at POLL_INTERVAL = 30).
    MAX_ATTEMPTS = 20

    # Fetch a single tweet by id and return it in Birdsong's internal hash schema.
    #
    # @param id [String] the tweet id
    # @return [Hash] the same shape returned by TweetScraper#parse
    # @raise [Birdsong::NoTweetFoundError] when the job fails, times out, or returns no result
    def fetch(id)
      job = create_job(id)
      job_id = job["job_id"]
      raise Birdsong::NoTweetFoundError if job_id.nil?

      result = poll_until_done(job_id)
      transform(result)
    end

  private

    # POST the scrape request and return the parsed job description.
    def create_job(id)
      response = Typhoeus.post(
        endpoint("v1/scrape/x/tweet/#{id}?max_items=1"),
        headers: headers,
        body: ""
      )
      handle_response(response)
    end

    # GET the job every POLL_INTERVAL seconds until it is `done` (returns the result) or
    # `failed`/timed out (raises NoTweetFoundError).
    def poll_until_done(job_id)
      MAX_ATTEMPTS.times do
        response = Typhoeus.get(endpoint("v1/scrape/jobs/#{job_id}"), headers: headers)
        body = handle_response(response)

        case body["status"]
        when "done"
          result = body["result"]
          raise Birdsong::NoTweetFoundError if result.nil?
          return result
        when "failed"
          raise Birdsong::NoTweetFoundError
        end

        sleep POLL_INTERVAL
      end

      # Exhausted all attempts without reaching a terminal state.
      raise Birdsong::NoTweetFoundError
    end

    # Map Antena's `result` payload onto Birdsong's internal tweet hash schema.
    def transform(result)
      author = result["author"] || {}

      images = []
      videos = []
      video_preview_images = []
      video_file_type = nil

      Array(result["media"]).each do |media|
        case media["type"]
        when "photo"
          images << Birdsong.retrieve_media(media["url"])
        when "video"
          video_preview_images << Birdsong.retrieve_media(media["poster_url"])
          videos << Birdsong.retrieve_media(media["url"])
          video_file_type = "video"
        when "animated_gif"
          video_preview_images << Birdsong.retrieve_media(media["poster_url"])
          videos << Birdsong.retrieve_media(media["url"])
          video_file_type = "animated_gif"
        end
      end

      screenshot_file = result["screenshot_url"] ? Birdsong.retrieve_media(result["screenshot_url"]) : nil

      user = {
        id: author["author_id"],
        name: author["display_name"],
        username: author["handle"],
        sign_up_date: author["account_created_at"],
        location: author["location"],
        profile_image_url: author["avatar_url"],
        description: author["description"],
        followers_count: author["followers_count"],
        following_count: author["following_count"],
        tweet_count: author["tweets_count"],
        listed_count: author["listed_count"],
        verified: author["is_verified"],
        url: author["url"]
      }

      {
        images: images,
        videos: videos,
        video_preview_images: video_preview_images,
        screenshot_file: screenshot_file,
        text: result["text"],
        date: result["created_at"],
        number_of_likes: result.dig("engagement", "like"),
        user: user,
        id: result["tweet_id"],
        language: result["language"],
        video_file_type: video_file_type
      }
    end

    # Build a fully-qualified endpoint from the configured base. Honors a base with or
    # without a trailing slash.
    def endpoint(path)
      base = Birdsong.antena_base_endpoint.to_s
      base += "/" unless base.end_with?("/")
      "#{base}#{path}"
    end

    def headers
      {
        "accept" => "application/json",
        "Authorization" => "Bearer #{Birdsong.antena_token}"
      }
    end

    # Parse a JSON response, raising NoTweetFoundError on non-success or unparseable bodies.
    def handle_response(response)
      raise Birdsong::NoTweetFoundError unless response.success?

      JSON.parse(response.body)
    rescue JSON::ParserError
      raise Birdsong::NoTweetFoundError
    end
  end
end
