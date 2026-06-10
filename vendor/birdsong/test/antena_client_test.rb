# frozen_string_literal: true

require "test_helper"
require "date"
require "json"

# Tests for the Antena REST API bypass. These stub Typhoeus so they don't hit the
# network or a real browser.
class AntenaClientTest < Minitest::Test
  JOB_ID = "d1680374-9d16-4aaa-b82d-fe167c0c8053"
  TWEET_ID = "2064037313848463444"

  def setup
    Typhoeus::Expectation.clear

    @original_token = Birdsong.antena_token
    @original_base = Birdsong.antena_base_endpoint
    @original_save_media = Birdsong.save_media

    Birdsong.antena_token = "test-token"
    Birdsong.antena_base_endpoint = "https://backend.antena.botalite.es/api/"
    # Don't actually download avatars/screenshots during the test.
    Birdsong.save_media = false
  end

  def teardown
    Typhoeus::Expectation.clear
    Birdsong.antena_token = @original_token
    Birdsong.antena_base_endpoint = @original_base
    Birdsong.save_media = @original_save_media
    cleanup_temp_folder
  end

  def stub_job(status:, result: nil)
    queued = { job_id: JOB_ID, status: "queued", tweet_id: TWEET_ID, cached: false }
    Typhoeus.stub(/v1\/scrape\/x\/tweet\/#{TWEET_ID}/).and_return(
      Typhoeus::Response.new(code: 200, body: queued.to_json)
    )

    job = { job_id: JOB_ID, status: status, tweet_id: TWEET_ID, cached: false }
    job[:result] = result if result
    Typhoeus.stub(/v1\/scrape\/jobs\/#{JOB_ID}/).and_return(
      Typhoeus::Response.new(code: 200, body: job.to_json)
    )
  end

  def sample_result
    {
      tweet_id: TWEET_ID,
      text: "Sample tweet text",
      created_at: "2026-06-08T17:30:18Z",
      language: "en",
      url: "https://x.com/i/status/#{TWEET_ID}",
      author: {
        handle: "ThobaneMazibuko",
        display_name: "Thobane",
        avatar_url: nil,
        is_verified: false,
        is_bot: false,
        author_id: "758212869666312192",
        account_created_at: "2016-07-27T08:10:09Z",
        description: "bio",
        location: "Pietermaritzburg, South Africa",
        followers_count: 1881,
        following_count: 2547,
        tweets_count: 190_525,
        listed_count: 0
      },
      engagement: { like: 27, quote: 0, reply: 0, retweet: 1, bookmark: 0 },
      media: [],
      screenshot_url: nil
    }
  end

  def test_done_job_maps_to_birdsong_schema
    stub_job(status: "done", result: sample_result)

    tweet = Birdsong::Tweet.lookup(TWEET_ID).first

    assert_instance_of Birdsong::Tweet, tweet
    assert_equal TWEET_ID, tweet.id
    assert_equal "Sample tweet text", tweet.text
    assert_equal "en", tweet.language
    assert_equal DateTime.parse("2026-06-08T17:30:18Z"), tweet.created_at

    assert_equal "ThobaneMazibuko", tweet.author.username
    assert_equal "Thobane", tweet.author.name
    assert_equal "758212869666312192", tweet.author.id
    assert_equal 1881, tweet.author.followers_count
    assert_equal 190_525, tweet.author.tweet_count
    # Nil avatar should fall back gracefully, and url defaults from the username.
    assert_nil tweet.author.profile_image_url
    # nil (not "") so blueprints that guard on nil skip File.open.
    assert_nil tweet.author.profile_image_file_name
    assert_equal "https://www.x.com/ThobaneMazibuko", tweet.author.url

    assert_empty tweet.images
    assert_empty tweet.videos
    assert_nil tweet.video_file_type
  end

  def test_author_without_account_created_at_does_not_raise
    result = sample_result
    result[:author][:account_created_at] = nil
    stub_job(status: "done", result: result)

    tweet = Birdsong::Tweet.lookup(TWEET_ID).first
    assert_instance_of Birdsong::Tweet, tweet
    assert_nil tweet.author.created_at
  end

  def test_failed_job_raises_no_tweet_found
    stub_job(status: "failed")

    assert_raises Birdsong::NoTweetFoundError do
      Birdsong::Tweet.lookup(TWEET_ID)
    end
  end

  def test_photo_media_is_mapped_to_images
    result = sample_result
    result[:media] = [{ url: "https://example.com/pic.jpg", type: "photo", width: 100, height: 100 }]
    stub_job(status: "done", result: result)

    tweet = Birdsong::Tweet.lookup(TWEET_ID).first
    assert_equal 1, tweet.images.count
    assert_empty tweet.videos
  end

  def test_video_media_is_mapped_to_videos
    result = sample_result
    result[:media] = [{
      url: "https://example.com/vid.mp4",
      type: "video",
      poster_url: "https://example.com/poster.jpg",
      bitrate: 2_176_000
    }]
    stub_job(status: "done", result: result)

    tweet = Birdsong::Tweet.lookup(TWEET_ID).first
    assert_equal 1, tweet.videos.count
    assert_equal 1, tweet.video_preview_images.count
    assert_equal "video", tweet.video_file_type
    assert_empty tweet.images
  end
end
