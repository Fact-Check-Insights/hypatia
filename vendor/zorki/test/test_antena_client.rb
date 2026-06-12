# frozen_string_literal: true

require "test_helper"
require "date"
require "json"
require "typhoeus"

# Tests for the Antena REST API bypass. These stub Typhoeus so they don't hit the
# network or a real browser.
class AntenaClientTest < Minitest::Test
  JOB_ID = "adbe7fa0-814a-4826-88be-9e6c93672458"
  POST_ID = "3702243650317691971"
  SHORTCODE = "DNhAvwRIaxD"

  # Zorki.retrieve_media rejects anything 100 bytes or smaller, so the stubbed bodies must be
  # padded past that. The leading marker is what we assert on to prove the source.
  BUCKET_BODY = "BUCKET#{'.' * 200}"
  PLATFORM_BODY = "PLATFORM#{'.' * 200}"

  def setup
    Typhoeus::Expectation.clear

    @original_token = Zorki.antena_token
    @original_base = Zorki.antena_base_endpoint

    Zorki.antena_token = "test-token"
    Zorki.antena_base_endpoint = "https://antena.backend.botalite.es/api/"
  end

  def teardown
    Typhoeus::Expectation.clear
    Zorki.antena_token = @original_token
    Zorki.antena_base_endpoint = @original_base
    cleanup_temp_folder
  end

  # Stub the create-job POST, the poll GET, and any media download. Media downloads from
  # Antena's bucket (your-objectstorage) return "BUCKET"; anything pointing at an Instagram
  # host returns "PLATFORM" so a test can prove we never download from the platform.
  def stub_job(status:, result: nil)
    Typhoeus.stub(/v1\/scrape\/instagram\/post/).and_return(
      Typhoeus::Response.new(code: 200, body: { job_id: JOB_ID, status: "queued" }.to_json)
    )

    job = { job_id: JOB_ID, status: status, platform: "instagram", post_id: SHORTCODE }
    job[:result] = result if result
    Typhoeus.stub(/v1\/scrape\/jobs\/#{JOB_ID}/).and_return(
      Typhoeus::Response.new(code: 200, body: job.to_json)
    )

    Typhoeus.stub(/your-objectstorage/).and_return(Typhoeus::Response.new(code: 200, body: BUCKET_BODY))
    Typhoeus.stub(/cdninstagram|instagram\.com/).and_return(Typhoeus::Response.new(code: 200, body: PLATFORM_BODY))
  end

  # A single-photo post with an author that (like the real Antena payload) returns null for
  # all of its counts and its bio.
  def sample_result(media: nil)
    {
      post_id: POST_ID,
      platform: "instagram",
      text: "Sample post text",
      created_at: "2025-08-19T00:04:17Z",
      language: "es",
      url: "https://www.instagram.com/p/#{SHORTCODE}",
      author: {
        handle: "ahorraconayuda",
        display_name: "Isaac Morales Garcia",
        avatar_url: "https://fsn1.your-objectstorage.com/botalite-antena/avatars/instagram/50285783635.jpg?sig=a",
        is_verified: false,
        is_bot: false,
        author_id: "50285783635",
        account_created_at: nil,
        description: nil,
        location: nil,
        followers_count: nil,
        following_count: nil,
        listed_count: nil,
        posts_count: nil
      },
      engagement: { like_count: 699, view_count: nil, comment_count: 25 },
      media: media || [{
        url: "https://scontent-mad1-1.cdninstagram.com/v/t51.82787-15/photo.webp?sig=x",
        type: "photo",
        s3_key: "media/instagram/#{POST_ID}/media0.jpg",
        s3_url: "https://fsn1.your-objectstorage.com/botalite-antena/media/instagram/#{POST_ID}/media0.jpg?sig=b"
      }],
      screenshot_url: "https://fsn1.your-objectstorage.com/botalite-antena/post_screenshots/instagram/#{POST_ID}/shot.png?sig=c"
    }
  end

  def test_done_job_maps_to_zorki_schema
    stub_job(status: "done", result: sample_result)

    post = Zorki::Post.lookup(SHORTCODE).first

    assert_instance_of Zorki::Post, post
    # The id is the shortcode (parity with the browser scraper), not the numeric post_id.
    assert_equal SHORTCODE, post.id
    assert_equal "Sample post text", post.text
    assert_equal 699, post.number_of_likes
    assert_equal DateTime.parse("2025-08-19T00:04:17Z"), post.date

    # The user is a Zorki::User object (matching the browser scraper's output).
    assert_instance_of Zorki::User, post.user
    assert_equal "Isaac Morales Garcia", post.user.name
    assert_equal "ahorraconayuda", post.user.username
    assert_equal "https://www.instagram.com/ahorraconayuda", post.user.profile_link
    assert_equal false, post.user.verified

    # A single photo lands in the images array; no video.
    assert_equal 1, post.image_file_names.count
    assert File.exist?(post.image_file_names.first)
    assert_nil post.video_file_name
    assert_nil post.video_preview_image
    assert post.screenshot_file
    assert File.exist?(post.screenshot_file)
  end

  def test_media_is_downloaded_from_bucket_not_platform_url
    stub_job(status: "done", result: sample_result)

    post = Zorki::Post.lookup(SHORTCODE).first

    # Media must come from the Antena bucket (s3_url), never the Instagram platform url.
    assert_equal BUCKET_BODY, File.read(post.image_file_names.first)
    assert_equal BUCKET_BODY, File.read(post.screenshot_file)
    assert_equal BUCKET_BODY, File.read(post.user.profile_image)
  end

  def test_carousel_post_returns_multiple_images
    media = [
      { type: "photo", url: "https://scontent.cdninstagram.com/a.webp",
        s3_url: "https://fsn1.your-objectstorage.com/botalite-antena/media/#{POST_ID}/m0.jpg?sig=1" },
      { type: "photo", url: "https://scontent.cdninstagram.com/b.webp",
        s3_url: "https://fsn1.your-objectstorage.com/botalite-antena/media/#{POST_ID}/m1.jpg?sig=2" },
      { type: "photo", url: "https://scontent.cdninstagram.com/c.webp",
        s3_url: "https://fsn1.your-objectstorage.com/botalite-antena/media/#{POST_ID}/m2.jpg?sig=3" }
    ]
    stub_job(status: "done", result: sample_result(media: media))

    post = Zorki::Post.lookup(SHORTCODE).first
    assert_equal 3, post.image_file_names.count
    assert_nil post.video_file_name
  end

  def test_video_post_populates_video_and_preview
    media = [{
      type: "video",
      url: "https://scontent.cdninstagram.com/video.mp4",
      poster_url: "https://scontent.cdninstagram.com/poster.jpg",
      s3_url: "https://fsn1.your-objectstorage.com/botalite-antena/media/#{POST_ID}/v0.mp4?sig=v",
      poster_s3_url: "https://fsn1.your-objectstorage.com/botalite-antena/media/#{POST_ID}/v0_poster.jpg?sig=p"
    }]
    stub_job(status: "done", result: sample_result(media: media))

    post = Zorki::Post.lookup(SHORTCODE).first
    assert_empty post.image_file_names
    assert post.video_file_name
    assert_equal BUCKET_BODY, File.read(post.video_file_name)
    assert post.video_preview_image
    assert_equal BUCKET_BODY, File.read(post.video_preview_image)
  end

  def test_failed_job_raises_content_unavailable
    stub_job(status: "failed")

    assert_raises Zorki::ContentUnavailableError do
      Zorki::Post.lookup(SHORTCODE)
    end
  end

  # `profile`, `profile_image_url` and the `number_of_*` counts are NOT NULL downstream;
  # Antena sends null for all of them when a user has no public data.
  def test_null_author_fields_are_coerced
    stub_job(status: "done", result: sample_result)

    post = Zorki::Post.lookup(SHORTCODE).first
    assert_equal "", post.user.profile
    assert_equal 0, post.user.number_of_posts
    assert_equal 0, post.user.number_of_followers
    assert_equal 0, post.user.number_of_following
    # avatar_url is present in the sample, so profile_image_url is the bucket url string.
    assert post.user.profile_image_url.start_with?("https://")
  end

  # Worst case: Antena returns an author with everything null and no engagement block. Every
  # NOT NULL column must still get a safe default rather than crashing.
  def test_completely_empty_author_and_engagement_are_guarded
    result = sample_result
    result[:author] = { "handle" => "someone" }
    result.delete(:engagement)
    stub_job(status: "done", result: result)

    post = Zorki::Post.lookup(SHORTCODE).first
    assert_equal "", post.user.name
    assert_equal "someone", post.user.username
    assert_equal 0, post.user.number_of_posts
    assert_equal 0, post.user.number_of_followers
    assert_equal 0, post.user.number_of_following
    assert_equal false, post.user.verified
    assert_equal "", post.user.profile
    assert_equal "", post.user.profile_image_url
    assert_equal 0, post.number_of_likes
  end

  def test_null_avatar_is_coerced_to_empty_string
    result = sample_result
    result[:author][:avatar_url] = nil
    stub_job(status: "done", result: result)

    post = Zorki::Post.lookup(SHORTCODE).first
    assert_equal "", post.user.profile_image_url
    assert_nil post.user.profile_image
  end
end
