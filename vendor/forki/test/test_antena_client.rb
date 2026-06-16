# frozen_string_literal: true

require "test_helper"
require "date"
require "json"
require "typhoeus"

# Tests for the Antena REST API bypass. These stub Typhoeus so they don't hit the
# network or a real browser.
class AntenaClientTest < Minitest::Test
  JOB_ID = "5379ceae-e9ca-4d3c-b3ab-24ce8696e3a3"
  POST_ID = "122181191060891571"
  URL = "https://www.facebook.com/photo/?fbid=#{POST_ID}&set=a.122141941118891571"

  def setup
    Typhoeus::Expectation.clear

    @original_token = Forki.antena_token
    @original_base = Forki.antena_base_endpoint

    Forki.antena_token = "test-token"
    Forki.antena_base_endpoint = "https://antena.backend.botalite.es/api/"
  end

  def teardown
    Typhoeus::Expectation.clear
    Forki.antena_token = @original_token
    Forki.antena_base_endpoint = @original_base
    cleanup_temp_folder
  end

  # Stub the create-job POST, the poll GET, and any media download. Media downloads from
  # Antena's bucket (your-objectstorage) return "BUCKET"; anything pointing at a Facebook
  # host returns "PLATFORM" so a test can prove we never download post media from the platform.
  def stub_job(status:, result: nil)
    Typhoeus.stub(/v1\/scrape\/facebook\/post/).and_return(
      Typhoeus::Response.new(code: 200, body: { job_id: JOB_ID, status: "queued" }.to_json)
    )

    job = { job_id: JOB_ID, status: status, platform: "facebook", post_id: POST_ID }
    job[:result] = result if result
    Typhoeus.stub(/v1\/scrape\/jobs\/#{JOB_ID}/).and_return(
      Typhoeus::Response.new(code: 200, body: job.to_json)
    )

    Typhoeus.stub(/your-objectstorage/).and_return(Typhoeus::Response.new(code: 200, body: "BUCKET"))
    Typhoeus.stub(/fbcdn|facebook\.com/).and_return(Typhoeus::Response.new(code: 200, body: "PLATFORM"))
  end

  # A single-photo post whose author (like the real Antena payload) returns null for the
  # handle and all of its counts.
  def sample_result(media: nil, engagement: nil)
    {
      post_id: POST_ID,
      platform: "facebook",
      text: "Sample post text",
      created_at: "2026-06-15T23:22:09Z",
      language: "en",
      url: URL,
      author: {
        handle: nil,
        display_name: "PipTalkies",
        avatar_url: "https://scontent-mad1-1.xx.fbcdn.net/v/t39.30808-1/avatar.jpg?sig=a",
        is_verified: false,
        is_bot: false,
        author_id: "61576747142043",
        account_created_at: nil,
        description: nil,
        location: nil,
        followers_count: nil,
        following_count: nil,
        listed_count: nil,
        posts_count: nil
      },
      engagement: engagement || { like_count: 352, view_count: nil, comment_count: nil },
      media: media || [{
        url: "https://scontent-mad2-1.xx.fbcdn.net/v/t39.30808-6/photo.jpg?sig=x",
        type: "photo",
        s3_key: "media/facebook/#{POST_ID}/media0.jpg",
        s3_url: "https://fsn1.your-objectstorage.com/botalite-antena/media/facebook/#{POST_ID}/media0.jpg?sig=b"
      }],
      screenshot_url: "https://fsn1.your-objectstorage.com/botalite-antena/post_screenshots/facebook/#{POST_ID}/shot.png?sig=c"
    }
  end

  def test_done_job_maps_to_forki_schema
    stub_job(status: "done", result: sample_result)

    post = Forki::Post.lookup(URL).first

    assert_instance_of Forki::Post, post
    assert_equal POST_ID, post.id
    assert_equal URL, post.url
    assert_equal "Sample post text", post.text
    assert_equal false, post.has_video

    # created_at must be a Unix timestamp (zenodotus calls Time.at on it), not the ISO string.
    assert_kind_of Integer, post.created_at
    assert_equal DateTime.parse("2026-06-15T23:22:09Z").to_time.to_i, post.created_at

    # reactions is a hash keyed by reaction type; zenodotus reads reactions["num_likes"].
    assert_equal 352, post.reactions[:num_likes]

    # The user is a Forki::User object built from the post author.
    assert_instance_of Forki::User, post.user
    assert_equal "PipTalkies", post.user.name
    assert_equal "61576747142043", post.user.id
    # Handle is null, so the profile link falls back to the numeric id.
    assert_equal "https://www.facebook.com/61576747142043", post.user.profile_link
    assert_equal false, post.user.verified
    assert_equal "", post.user.profile

    assert post.image_file
    assert File.exist?(post.image_file)
    assert post.screenshot_file
    assert File.exist?(post.screenshot_file)
  end

  def test_media_is_downloaded_from_bucket_not_platform_url
    stub_job(status: "done", result: sample_result)

    post = Forki::Post.lookup(URL).first

    # Post media must come from the Antena bucket (s3_url), never the Facebook platform url.
    assert_equal "BUCKET", File.read(post.image_file)
    assert_equal "BUCKET", File.read(post.screenshot_file)
  end

  def test_video_post_populates_video_files_and_previews
    media = [{
      type: "video",
      url: "https://scontent.fbcdn.net/video.mp4",
      poster_url: "https://scontent.fbcdn.net/poster.jpg",
      s3_url: "https://fsn1.your-objectstorage.com/botalite-antena/media/#{POST_ID}/v0.mp4?sig=v",
      poster_s3_url: "https://fsn1.your-objectstorage.com/botalite-antena/media/#{POST_ID}/v0_poster.jpg?sig=p"
    }]
    stub_job(status: "done", result: sample_result(media: media))

    post = Forki::Post.lookup(URL).first
    assert_equal true, post.has_video
    assert_equal [], post.image_file
    assert_equal 1, post.video_files.count
    assert_equal "BUCKET", File.read(post.video_files.first)
    assert_equal 1, post.video_preview_image_files.count
    assert_equal "BUCKET", File.read(post.video_preview_image_files.first)
  end

  def test_failed_job_raises_content_unavailable
    stub_job(status: "failed")

    assert_raises Forki::ContentUnavailableError do
      Forki::Post.lookup(URL)
    end
  end

  # Defensive: an author with everything null and a missing engagement block must not crash,
  # and the post must still carry a non-nil user (facebook_posts.author_id is NOT NULL).
  def test_null_fields_are_guarded
    result = sample_result(engagement: {})
    result[:author] = { "author_id" => "999", "display_name" => nil, "handle" => nil }
    result[:created_at] = nil
    stub_job(status: "done", result: result)

    post = Forki::Post.lookup(URL).first
    assert_instance_of Forki::User, post.user
    assert_equal "999", post.user.id
    assert_nil post.user.name
    assert_equal "", post.user.profile
    assert_equal "", post.user.profile_image_url
    assert_equal false, post.user.verified
    assert_equal "https://www.facebook.com/999", post.user.profile_link
    assert_nil post.created_at
    assert_nil post.num_comments
    assert_nil post.num_views
    assert_nil post.reactions[:num_likes]
  end

  def test_null_avatar_does_not_download_and_is_coerced
    result = sample_result
    result[:author][:avatar_url] = nil
    stub_job(status: "done", result: result)

    post = Forki::Post.lookup(URL).first
    assert_equal "", post.user.profile_image_url
    assert_nil post.user.profile_image_file
  end
end
