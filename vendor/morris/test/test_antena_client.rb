# frozen_string_literal: true

require "test_helper"
require "date"
require "json"

# Tests for the Antena REST API bypass. These stub Typhoeus so they don't hit the
# network or a real browser.
class AntenaClientTest < Minitest::Test
  JOB_ID = "1fbc41ca-abb1-4222-89ff-62bb04892236"
  POST_ID = "7463884292981099798"
  URL = "https://www.tiktok.com/@martared/video/#{POST_ID}"

  def setup
    Typhoeus::Expectation.clear

    @original_token = Morris.antena_token
    @original_base = Morris.antena_base_endpoint

    Morris.antena_token = "test-token"
    Morris.antena_base_endpoint = "https://backend.antena.botalite.es/api/"
  end

  def teardown
    Typhoeus::Expectation.clear
    Morris.antena_token = @original_token
    Morris.antena_base_endpoint = @original_base
    cleanup_temp_folder
  end

  # Stub the create-job POST, the poll GET, and any media download. Media downloads from
  # Antena's bucket (your-objectstorage) return "BUCKET"; anything pointing at a TikTok
  # host returns "PLATFORM" so a test can prove we never download from the platform.
  def stub_job(status:, result: nil)
    Typhoeus.stub(/v1\/scrape\/tiktok\/post/).and_return(
      Typhoeus::Response.new(code: 200, body: { job_id: JOB_ID, status: "queued" }.to_json)
    )

    job = { job_id: JOB_ID, status: status, platform: "tiktok", post_id: POST_ID }
    job[:result] = result if result
    Typhoeus.stub(/v1\/scrape\/jobs\/#{JOB_ID}/).and_return(
      Typhoeus::Response.new(code: 200, body: job.to_json)
    )

    Typhoeus.stub(/your-objectstorage/).and_return(Typhoeus::Response.new(code: 200, body: "BUCKET"))
    Typhoeus.stub(/tiktokcdn/).and_return(Typhoeus::Response.new(code: 200, body: "AVATAR"))
    Typhoeus.stub(/tiktok\.com/).and_return(Typhoeus::Response.new(code: 200, body: "PLATFORM"))
  end

  def sample_result
    {
      post_id: POST_ID,
      platform: "tiktok",
      text: "Sample post text",
      created_at: "2025-01-25T16:03:11Z",
      language: "es",
      url: URL,
      author: {
        handle: "martared",
        display_name: "MARTA RED",
        avatar_url: "https://p16-common-sign.tiktokcdn-eu.com/avatar.jpeg",
        is_verified: false,
        is_bot: false,
        author_id: "7302814960269362209",
        account_created_at: nil,
        description: "bio",
        location: nil,
        followers_count: 27_300,
        following_count: 1,
        listed_count: nil,
        posts_count: 776
      },
      engagement: { like_count: 19_500, view_count: 826_600, comment_count: 2138 },
      media: [{
        url: "https://v16-webapp-prime.tiktok.com/video/tos/no1a/playable.mp4",
        type: "video",
        s3_key: "media/tiktok/#{POST_ID}/media0.mp4",
        poster_url: "https://p16-common-sign.tiktokcdn-eu.com/poster.jpg",
        poster_s3_key: "media/tiktok/#{POST_ID}/media0_poster.jpg",
        s3_url: "https://fsn1.your-objectstorage.com/botalite-antena/media/#{POST_ID}/media0.mp4?sig=abc",
        poster_s3_url: "https://fsn1.your-objectstorage.com/botalite-antena/media/#{POST_ID}/media0_poster.jpg?sig=def"
      }],
      screenshot_url: "https://fsn1.your-objectstorage.com/botalite-antena/post_screenshots/#{POST_ID}/shot.png?sig=ghi"
    }
  end

  def test_done_job_maps_to_morris_schema
    stub_job(status: "done", result: sample_result)

    post = Morris::Post.lookup(URL).first

    assert_instance_of Morris::Post, post
    assert_equal POST_ID, post.id
    assert_equal "Sample post text", post.text
    assert_equal 19_500, post.number_of_likes
    assert_equal DateTime.parse("2025-01-25T16:03:11Z"), post.date

    # The user is a plain hash (matching the browser scraper's output).
    assert_equal "MARTA RED", post.user[:name]
    assert_equal "martared", post.user[:username]
    assert_equal 776, post.user[:number_of_posts]
    assert_equal 27_300, post.user[:number_of_followers]
    assert_equal 1, post.user[:number_of_following]
    assert_equal "bio", post.user[:profile]
    assert_equal "https://www.tiktok.com/@martared", post.user[:profile_link]
    assert_equal false, post.user[:verified]

    # Media is downloaded to local temp files.
    assert post.video_file_name
    assert File.exist?(post.video_file_name)
    assert post.video_preview_image
    assert File.exist?(post.video_preview_image)
    assert post.screenshot_file
    assert File.exist?(post.screenshot_file)
  end

  def test_video_is_downloaded_from_bucket_not_platform_url
    stub_job(status: "done", result: sample_result)

    post = Morris::Post.lookup(URL).first

    # The video must come from the Antena bucket (s3_url), never the TikTok platform url.
    assert_equal "BUCKET", File.read(post.video_file_name)
    assert_equal "BUCKET", File.read(post.video_preview_image)
    assert_equal "BUCKET", File.read(post.screenshot_file)
  end

  def test_failed_job_raises_content_unavailable
    stub_job(status: "failed")

    assert_raises Morris::ContentUnavailableError do
      Morris::Post.lookup(URL)
    end
  end

  def test_author_without_account_created_at_does_not_raise
    result = sample_result
    result[:author][:account_created_at] = nil
    stub_job(status: "done", result: result)

    post = Morris::Post.lookup(URL).first
    assert_instance_of Morris::Post, post
  end
end
