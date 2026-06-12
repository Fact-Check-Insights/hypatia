# frozen_string_literal: true

require "date"
require "json"
require "typhoeus"

module Zorki
  # Client for the Antena REST API. When `ANTENA_TOKEN` is present this replaces the
  # browser-based scraping with a call to Antena, returning the exact same post hash
  # schema that `PostScraper#parse` produces so that `Post`/`User` consume it unchanged.
  #
  # Note on media: the Antena API returns both the original Instagram platform url (`url`)
  # and a copy it has already downloaded into its own object storage (`s3_url`). We always
  # download from the bucket url (`s3_url`/`poster_s3_url`), never from the Instagram platform
  # url, because the platform urls are signed/expiring and not reliably downloadable later.
  class AntenaClient
    # How often to poll the job endpoint, in seconds.
    POLL_INTERVAL = 30

    # Maximum number of polls before giving up (~10 minutes at POLL_INTERVAL = 30).
    MAX_ATTEMPTS = 20

    # Fetch a single post by its Instagram shortcode and return it in Zorki's internal
    # hash schema.
    #
    # @param id [String] the Instagram post shortcode (e.g. "DNRJxzVC6wt")
    # @return [Hash] the same shape returned by PostScraper#parse
    # @raise [Zorki::ContentUnavailableError] when the job fails, times out, or returns no result
    def fetch(id)
      job = create_job(id)
      job_id = job["job_id"]
      raise Zorki::ContentUnavailableError.new if job_id.nil?

      result = poll_until_done(job_id)
      transform(result, id)
    end

  private

    # POST the scrape request and return the parsed job description. The Instagram endpoint
    # takes the full post url in a JSON body. We only receive the shortcode, so we rebuild the
    # canonical /p/ url (Instagram serves reels/tv under /p/ too).
    def create_job(id)
      response = Typhoeus.post(
        endpoint("v1/scrape/instagram/post?max_items=1"),
        headers: headers.merge("Content-Type" => "application/json"),
        body: { post: "https://www.instagram.com/p/#{id}" }.to_json
      )
      handle_response(response)
    end

    # GET the job every POLL_INTERVAL seconds until it is `done` (returns the result) or
    # `failed`/timed out (raises ContentUnavailableError).
    def poll_until_done(job_id)
      MAX_ATTEMPTS.times do
        response = Typhoeus.get(endpoint("v1/scrape/jobs/#{job_id}"), headers: headers)
        body = handle_response(response)

        case body["status"]
        when "done"
          result = body["result"]
          raise Zorki::ContentUnavailableError.new if result.nil?
          return result
        when "failed"
          raise Zorki::ContentUnavailableError.new
        end

        sleep POLL_INTERVAL
      end

      # Exhausted all attempts without reaching a terminal state.
      raise Zorki::ContentUnavailableError.new
    end

    # Map Antena's `result` payload onto Zorki's internal post hash schema.
    def transform(result, id)
      author = result["author"] || {}

      images = []
      video = nil
      video_preview_image = nil

      # Instagram posts may be a single photo, a carousel of photos, or a video/reel. Pull
      # the bucket copies (never the expiring Instagram platform urls).
      Array(result["media"]).each do |media|
        case media["type"]
        when "photo", "image"
          images << download(media["s3_url"])
        when "video"
          video = download(media["s3_url"])
          video_preview_image = download(media["poster_s3_url"])
        end
      end
      images.compact!

      screenshot_file = download(result["screenshot_url"])

      handle = author["handle"]

      # Every field below maps to a NOT NULL column in zenodotus (instagram_users /
      # instagram_posts). Antena can return null for any of them, so each one is coerced to a
      # safe default (the browser scraper produced "" / 0 / false) to avoid a NotNullViolation.
      # The only exception is `date`, which has no sensible default — a missing timestamp means
      # the post is genuinely broken, so we let it surface rather than fabricate a date.
      user = Zorki::User.new(
        name: author["display_name"].to_s,
        username: handle.to_s,
        number_of_posts: author["posts_count"] || 0,
        number_of_followers: author["followers_count"] || 0,
        number_of_following: author["following_count"] || 0,
        verified: author["is_verified"] || false,
        profile: author["description"].to_s,
        profile_link: handle ? "https://www.instagram.com/#{handle}" : nil,
        profile_image: download(author["avatar_url"]),
        profile_image_url: author["avatar_url"].to_s
      )

      {
        images: images,
        video: video,
        video_preview_image: video_preview_image,
        screenshot_file: screenshot_file,
        text: result["text"].to_s,
        date: parse_date(result["created_at"]),
        number_of_likes: result.dig("engagement", "like_count") || 0,
        user: user,
        # Preserve parity with the browser scraper, which returns the shortcode as the id
        # (Antena's `result.post_id` is the numeric internal id, which differs).
        id: id
      }
    end

    # Download a remote asset to a local temp file, or return nil when there's no url.
    def download(url)
      url.nil? || url.empty? ? nil : Zorki.retrieve_media(url)
    end

    # Antena returns ISO8601 timestamps; guard against a missing value.
    def parse_date(value)
      value.nil? || value.to_s.empty? ? nil : DateTime.parse(value)
    end

    # Build a fully-qualified endpoint from the configured base. Honors a base with or
    # without a trailing slash.
    def endpoint(path)
      base = Zorki.antena_base_endpoint.to_s
      base += "/" unless base.end_with?("/")
      "#{base}#{path}"
    end

    def headers
      {
        "accept" => "application/json",
        "Authorization" => "Bearer #{Zorki.antena_token}"
      }
    end

    # Parse a JSON response, raising ContentUnavailableError on non-success or unparseable bodies.
    def handle_response(response)
      raise Zorki::ContentUnavailableError.new unless response.success?

      JSON.parse(response.body)
    rescue JSON::ParserError
      raise Zorki::ContentUnavailableError.new
    end
  end
end
