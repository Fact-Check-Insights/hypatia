# frozen_string_literal: true

require "date"
require "json"
require "typhoeus"

module Forki
  # Client for the Antena REST API. When `ANTENA_TOKEN` is present this replaces the
  # browser-based scraping with a call to Antena, returning the exact same post hash
  # schema that `PostScraper#parse` produces so that `Post`/`User` consume it unchanged.
  #
  # Note on media: the Antena API returns both the original Facebook platform url (`url`)
  # and a copy it has already downloaded into its own object storage (`s3_url`). We always
  # download post media from the bucket url (`s3_url`/`poster_s3_url`), never from the
  # Facebook platform url, because the platform urls are signed/expiring and not reliably
  # downloadable later. (Author avatars are only served from the platform CDN, so those are
  # the one exception.)
  class AntenaClient
    # How often to poll the job endpoint, in seconds.
    POLL_INTERVAL = 30

    # Maximum number of polls before giving up (~10 minutes at POLL_INTERVAL = 30).
    MAX_ATTEMPTS = 20

    # Fetch a single post by its Facebook url and return it in Forki's internal hash schema.
    #
    # @param url [String] the Facebook post url
    # @return [Hash] the same shape returned by PostScraper#parse
    # @raise [Forki::ContentUnavailableError] when the job fails, times out, or returns no result
    def fetch(url)
      job = create_job(url)
      job_id = job["job_id"]
      raise Forki::ContentUnavailableError.new if job_id.nil?

      result = poll_until_done(job_id)
      transform(result, url)
    end

  private

    # POST the scrape request and return the parsed job description. The Facebook endpoint
    # takes the full post url in a JSON body.
    def create_job(url)
      response = Typhoeus.post(
        endpoint("v1/scrape/facebook/post?max_items=1"),
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
          raise Forki::ContentUnavailableError.new if result.nil?
          return result
        when "failed"
          raise Forki::ContentUnavailableError.new
        end

        sleep POLL_INTERVAL
      end

      # Exhausted all attempts without reaching a terminal state.
      raise Forki::ContentUnavailableError.new
    end

    # Map Antena's `result` payload onto Forki's internal post hash schema.
    def transform(result, url)
      author = result["author"] || {}
      engagement = result["engagement"] || {}

      images = []
      video_files = []
      video_preview_image_files = []
      video_preview_image_urls = []
      image_url = nil

      # Pull the bucket copies (never the expiring Facebook platform urls).
      Array(result["media"]).each do |media|
        case media["type"]
        when "photo", "image"
          images << download(media["s3_url"])
          image_url ||= media["s3_url"]
        when "video"
          video_files << download(media["s3_url"])
          if media["poster_s3_url"]
            video_preview_image_files << download(media["poster_s3_url"])
            video_preview_image_urls << media["poster_s3_url"]
          end
        end
      end
      images.compact!
      video_files.compact!
      video_preview_image_files.compact!

      has_video = video_files.any?
      # Forki models a single image per post (text/video posts use []). Preserve that shape.
      image_file = has_video ? [] : (images.first || [])

      screenshot_file = download(result["screenshot_url"])

      {
        id: result["post_id"],
        url: url,
        text: result["text"].to_s,
        # zenodotus reads created_at with `Time.at`, so it must be a Unix timestamp, not the
        # ISO8601 string Antena returns. nil is tolerated downstream (posted_at is nullable).
        created_at: parse_timestamp(result["created_at"]),
        has_video: has_video,
        image_file: image_file,
        image_url: image_url,
        num_comments: engagement["comment_count"],
        # Antena does not expose a share count.
        num_shares: nil,
        num_views: engagement["view_count"],
        # Antena only gives an aggregate like_count; the browser scraper returns a hash keyed
        # by reaction type (num_likes, num_loves, ...). zenodotus reads reactions["num_likes"].
        reactions: { num_likes: engagement["like_count"] },
        video_files: video_files,
        video_preview_image_files: video_preview_image_files,
        video_preview_image_urls: video_preview_image_urls,
        screenshot_file: screenshot_file,
        user: build_user(author)
      }
    end

    # Build a Forki::User from the Antena author. The post requires a non-null author
    # downstream (facebook_posts.author_id is NOT NULL), and Antena always carries at least an
    # author_id/display_name, so we always return a user. Facebook author handles are often
    # null, so the profile link falls back to the numeric id.
    def build_user(author)
      handle = author["handle"]
      profile_link = if handle && !handle.to_s.empty?
                       "https://www.facebook.com/#{handle}"
                     elsif author["author_id"]
                       "https://www.facebook.com/#{author['author_id']}"
                     end

      Forki::User.new(
        name: author["display_name"],
        id: author["author_id"],
        number_of_followers: author["followers_count"],
        verified: author["is_verified"] || false,
        profile: author["description"].to_s,
        profile_link: profile_link,
        profile_image_file: download(author["avatar_url"]),
        profile_image_url: author["avatar_url"].to_s,
        # Antena does not expose a page "likes" count separate from post reactions.
        number_of_likes: nil
      )
    end

    # Download a remote asset to a local temp file, or return nil when there's no url.
    def download(url)
      url.nil? || url.to_s.empty? ? nil : Forki.retrieve_media(url)
    end

    # Antena returns ISO8601 timestamps; convert to a Unix epoch integer for `Time.at`
    # downstream. Guards against missing or already-numeric values.
    def parse_timestamp(value)
      return nil if value.nil? || value.to_s.empty?
      return value if value.is_a?(Integer)

      DateTime.parse(value.to_s).to_time.to_i
    rescue ArgumentError
      nil
    end

    # Build a fully-qualified endpoint from the configured base. Honors a base with or
    # without a trailing slash.
    def endpoint(path)
      base = Forki.antena_base_endpoint.to_s
      base += "/" unless base.end_with?("/")
      "#{base}#{path}"
    end

    def headers
      {
        "accept" => "application/json",
        "Authorization" => "Bearer #{Forki.antena_token}"
      }
    end

    # Parse a JSON response, raising ContentUnavailableError on non-success or unparseable bodies.
    def handle_response(response)
      raise Forki::ContentUnavailableError.new unless response.success?

      JSON.parse(response.body)
    rescue JSON::ParserError
      raise Forki::ContentUnavailableError.new
    end
  end
end
