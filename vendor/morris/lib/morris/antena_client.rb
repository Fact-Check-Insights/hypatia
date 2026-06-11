# frozen_string_literal: true

require "date"
require "json"
require "typhoeus"

module Morris
  # Client for the Antena REST API. When `ANTENA_TOKEN` is present this replaces the
  # browser-based scraping with a call to Antena, returning the exact same post hash
  # schema that `PostScraper#parse` produces so that `Post`/`User` consume it unchanged.
  #
  # Note on media: the Antena API returns both the original TikTok platform url (`url`)
  # and a copy it has already downloaded into its own object storage (`s3_url`). We always
  # download from the bucket url (`s3_url`/`poster_s3_url`), never from the TikTok platform
  # url, because the platform urls are signed/expiring and not reliably downloadable later.
  class AntenaClient
    # How often to poll the job endpoint, in seconds.
    POLL_INTERVAL = 30

    # Maximum number of polls before giving up (~10 minutes at POLL_INTERVAL = 30).
    MAX_ATTEMPTS = 20

    # Fetch a single post by its TikTok url and return it in Morris's internal hash schema.
    #
    # @param url [String] the TikTok post url
    # @return [Hash] the same shape returned by PostScraper#parse
    # @raise [Morris::ContentUnavailableError] when the job fails, times out, or returns no result
    def fetch(url)
      job = create_job(url)
      job_id = job["job_id"]
      raise Morris::ContentUnavailableError.new if job_id.nil?

      result = poll_until_done(job_id)
      transform(result)
    end

  private

    # POST the scrape request and return the parsed job description. The TikTok endpoint
    # takes the full post url in a JSON body (unlike the X endpoint, which uses the id).
    def create_job(url)
      response = Typhoeus.post(
        endpoint("v1/scrape/tiktok/post?max_items=1"),
        headers: headers.merge("Content-Type" => "application/json"),
        body: { post: url }.to_json
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
          raise Morris::ContentUnavailableError.new if result.nil?
          return result
        when "failed"
          raise Morris::ContentUnavailableError.new
        end

        sleep POLL_INTERVAL
      end

      # Exhausted all attempts without reaching a terminal state.
      raise Morris::ContentUnavailableError.new
    end

    # Map Antena's `result` payload onto Morris's internal post hash schema.
    def transform(result)
      author = result["author"] || {}

      video = nil
      video_preview_image = nil

      # Morris models a single video per post. Take the first video media entry and pull
      # its bucket copies (never the expiring TikTok platform urls).
      video_media = Array(result["media"]).find { |media| media["type"] == "video" }
      if video_media
        video = download(video_media["s3_url"])
        video_preview_image = download(video_media["poster_s3_url"])
      end

      screenshot_file = download(result["screenshot_url"])

      user = {
        name: author["display_name"],
        username: author["handle"],
        number_of_posts: author["posts_count"],
        number_of_followers: author["followers_count"],
        number_of_following: author["following_count"],
        verified: author["is_verified"],
        # `profile` and `profile_image_url` are NOT NULL downstream, but Antena returns null
        # when a user has no bio/avatar (the browser scraper returned ""), so coerce to "".
        profile: author["description"].to_s,
        profile_link: author["handle"] ? "https://www.tiktok.com/@#{author['handle']}" : nil,
        profile_image: download(author["avatar_url"]),
        profile_image_url: author["avatar_url"].to_s
      }

      {
        video: video,
        video_preview_image: video_preview_image,
        screenshot_file: screenshot_file,
        text: result["text"],
        date: parse_date(result["created_at"]),
        number_of_likes: result.dig("engagement", "like_count"),
        user: user,
        id: result["post_id"]
      }
    end

    # Download a remote asset to a local temp file, or return nil when there's no url.
    def download(url)
      url.nil? || url.empty? ? nil : Morris.retrieve_media(url)
    end

    # Antena returns ISO8601 timestamps; guard against a missing value.
    def parse_date(value)
      value.nil? || value.to_s.empty? ? nil : DateTime.parse(value)
    end

    # Build a fully-qualified endpoint from the configured base. Honors a base with or
    # without a trailing slash.
    def endpoint(path)
      base = Morris.antena_base_endpoint.to_s
      base += "/" unless base.end_with?("/")
      "#{base}#{path}"
    end

    def headers
      {
        "accept" => "application/json",
        "Authorization" => "Bearer #{Morris.antena_token}"
      }
    end

    # Parse a JSON response, raising ContentUnavailableError on non-success or unparseable bodies.
    def handle_response(response)
      raise Morris::ContentUnavailableError.new unless response.success?

      JSON.parse(response.body)
    rescue JSON::ParserError
      raise Morris::ContentUnavailableError.new
    end
  end
end
