# frozen_string_literal: true

# A note: Some of these will fail non-deterministically. This is because Twitter/X is a shit show and
# their servers fail all the time. In that case, we just throw an error which should be caught
# (going to usually be Selenium::WebDriver::Error::NoSuchElementError) by whatever is using this library
# and retry later.

require "test_helper"
require "date"

class TweetTest < Minitest::Test
  def teardown
    cleanup_temp_folder
  end

  def test_that_a_tweet_is_created_with_id
    tweets = Birdsong::Tweet.lookup("1378268627615543296")
    assert_not_nil tweets
    assert_equal 1, tweets.count
    tweets.each { |tweet| assert_instance_of Birdsong::Tweet, tweet }
  end

  def test_that_a_tweet_with_a_nil_author_url_is_recreated
    tweets = Birdsong::Tweet.lookup("1651942285620256772")

    # This tweet's author url should not be nil anymore
    tweets.each { |tweet| assert_instance_of Birdsong::Tweet, tweet }
    tweets.each { |tweet| assert_not_nil tweet.author.url }
  end

  def test_that_a_tweet_raises_exception_with_invalid_id
    assert_raises Birdsong::InvalidIdError do
      Birdsong::Tweet.lookup("abcdef")
    end
  end

  def test_that_a_tweet_has_correct_attributes
    tweet = Birdsong::Tweet.lookup("1378268627615543296").first
    assert_equal "1378268627615543296", tweet.id
    assert_equal DateTime.parse("2021-04-03T08:50:22.000Z"), tweet.created_at
    assert_equal "Five years ago... #PanamaPapers #OnThisDay @ICIJorg @SZ https://t.co/hLMVuYOk3D https://t.co/8uJkbb6Pko", tweet.text
    assert_equal "en", tweet.language
    assert_equal "Frederik Obermaier", tweet.author.name
  end

  def test_that_a_tweet_cant_be_found_works
    assert_raises Birdsong::NoTweetFoundError do
      Birdsong::Tweet.lookup("19")
    end
  end

  def test_that_a_tweet_can_have_no_media
    tweet = Birdsong::Tweet.lookup("20").first
    assert_equal "20", tweet.id
    assert_not_nil tweet.images
    assert_equal 0, tweet.images.count
    assert_equal 0, tweet.videos.count
  end

  def test_that_a_tweet_can_have_a_single_image
    tweet = Birdsong::Tweet.lookup("1407341650737762304").first
    assert_not_nil tweet.images
    assert_equal 1, tweet.images.count
    assert_equal 0, tweet.videos.count

    tweet.images.each do |image_name|
          assert File.size(image_name) > 1000
        end
  end

  def test_that_a_tweet_can_have_a_slideshow
    tweet = Birdsong::Tweet.lookup("1407322444399099904").first
    assert_not_nil tweet.images
    assert_equal 4, tweet.images.count
    assert_equal 0, tweet.videos.count
    tweet.images.each do |image_name|
      assert File.size(image_name) > 1000
    end
  end

  def test_that_a_tweet_can_have_a_video
    tweet = Birdsong::Tweet.lookup("1407342630837657605").first
    assert_not_nil tweet.videos
    assert_equal 1, tweet.videos.count
    assert_equal 0, tweet.images.count
    assert_equal "video", tweet.video_file_type
    tweet.videos.each do |video_name|
      assert File.size(video_name) > 1000
    end
  end

  def test_that_a_tweet_can_have_a_video_preview
    tweet = Birdsong::Tweet.lookup("1407342630837657605").first
    assert !tweet.video_preview_images.empty?
  end

  def test_that_a_tweet_handles_no_variants_for_video
    tweet = Birdsong::Tweet.lookup("1258817692448051200").first
    assert_not_nil tweet.videos
    assert_equal 1, tweet.videos.count
    assert_equal 0, tweet.images.count
    tweet.videos.each do |video_name|
      assert File.size(video_name) > 1000
    end
  end

  def test_that_a_tweet_can_have_a_gif
    tweet = Birdsong::Tweet.lookup("1472873480249131012").first
    assert_not_nil tweet.videos
    assert_equal 0, tweet.images.count
    assert_equal 1, tweet.videos.count
    assert_equal "animated_gif", tweet.video_file_type
    tweet.videos.each do |video_name|
      assert File.size(video_name) > 1000
    end
  end

  def test_that_a_tweet_can_have_a_gif_preview
    tweet = Birdsong::Tweet.lookup("1472873480249131012").first
    assert !tweet.video_preview_images.empty?
  end

  def test_that_user_aliases_author
    tweet = Birdsong::Tweet.lookup("1472873480249131012").first
    assert_equal tweet.author, tweet.user
  end

  def test_that_a_tweet_with_a_suspended_author_fails
    assert_raises Birdsong::NoTweetFoundError do
      Birdsong::Tweet.lookup("1329846849210114052").first
    end
  end

  def test_another_url
    Birdsong::Tweet.lookup("1552221138037755904")
  end

  def test_another_url_2
    Birdsong::Tweet.lookup("1848168783057232074")
  end

  def test_mixed_media_posts
    Birdsong::Tweet.lookup("1835567947252634020")
  end

  def test_a_very_weird_one
    # https://x.com/EndWokeness/status/1835873305670128099?fbclid=IwY2xjawFY-lBleHRuA2FlbQIxMAABHbeSiI97zlbJqXzozcpL4_21e2JrEi1zD7kI4Q3CQnHfpKkvzqLBZcPaQQ_aem_psyDRKvN0sUOOdPrQ7QOog
    Birdsong::Tweet.lookup("1835873305670128099")
  end

  def test_a_post_with_mixed_media
    # https://x.com/SaadAbedine/status/1831611300356428158
    tweet = Birdsong::Tweet.lookup("1831611300356428158")
    assert tweet.first.videos.count == 1
    assert tweet.first.images.count == 1

    tweet.first.videos.each do |video_name|
      assert File.size(video_name) > 1000
    end

    tweet.first.images.each do |image_name|
      assert File.size(image_name) > 1000
    end
  end

  def test_multiple_video_in_tweet
    tweet = Birdsong::Tweet.lookup("1856091059664891951").first
    assert_not_nil tweet.videos
    assert_equal 0, tweet.images.count
    assert_equal 4, tweet.videos.count

    tweet.videos.each do |video_name|
      assert File.size(video_name) > 1000
    end
  end

  def test_a_post_with_an_image_and_video
    tweet = Birdsong::Tweet.lookup("1851408978544132410")
    assert tweet.first.videos.count == 1
    assert tweet.first.images.count == 1

    tweet.first.videos.each do |video_name|
      assert File.size(video_name) > 1000
    end

    tweet.first.images.each do |image_name|
      assert File.size(image_name) > 1000
    end
  end

  def test_another_post_with_video
    tweet = Birdsong::Tweet.lookup("1852022814066303034")
    assert tweet.first.videos.count == 1
    tweet.first.videos.each do |video_name|
      assert File.size(video_name) > 1000
    end
  end

  def test_another_post_with_video_2
    tweet = Birdsong::Tweet.lookup("1854422698106986902")
    assert tweet.first.videos.count == 1
    assert_not_nil tweet.first.screenshot_file
    tweet.first.videos.each do |video_name|
      assert File.size(video_name) > 1000
    end

    assert File.size(tweet.first.screenshot_file) > 1000
  end

  def test_another_post_with_video_3
    tweet = Birdsong::Tweet.lookup("1895544658799038933")
    assert tweet.first.videos.count == 1
    assert_not_nil tweet.first.screenshot_file
    tweet.first.videos.each do |video_name|
      assert File.size(video_name) > 1000
    end

    assert File.size(tweet.first.screenshot_file) > 1000
  end

  def test_multiple_video_in_tweet_2
    tweet = Birdsong::Tweet.lookup("1853732129697415386").first
    assert_not_nil tweet.videos
    assert_equal 1, tweet.images.count
    assert_equal 2, tweet.videos.count

    tweet.videos.each do |video_name|
      assert File.size(video_name) > 1000
    end

    tweet.video_preview_images do |image_name|
      assert File.size(image_name) > 1000
    end

    tweet.images.each do |image_name|
      assert File.size(image_name) > 1000
    end
  end

  def test_yet_another_link
    tweet = Birdsong::Tweet.lookup("1854422698106986902").first
    assert_not_nil(tweet)

    tweet.videos.each do |video_name|
      assert File.size(video_name) > 1000
    end
  end
end
