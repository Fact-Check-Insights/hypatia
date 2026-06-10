require "test_helper"

# rubocop:disable Metrics/ClassLength
class TwitterSourceTest < ActiveSupport::TestCase
  def setup; end

  # test "can send error via slack notification" do
  #   assert_nothing_raised do
  #     TwitterMediaSource.send_message_to_slack("Test message for Youtube Media Source")
  #   end
  # end

  test "can send error is there is an error while scraping" do
    assert_raise(MediaSource::HostError) do
      TwitterMediaSource.extract(Scrape.create({ url: "https://www.example.com" }))
    end
  end

  def test_invalid_tweet_url_raises_error
    assert_raises(MediaSource::HostError) do
      TwitterMediaSource.new(Scrape.create({ url: "https://twitter.com/20" }))
    end
  end

  def test_extract_tweet_id_ignores_photo_video_and_query_suffixes
    {
      "https://x.com/flyunitedng/status/2039294097463099457/photo/1" => "2039294097463099457",
      "https://x.com/world_upd/status/2062352285456568575/video/1"  => "2062352285456568575",
      "https://x.com/i/status/2064037313848463444"                  => "2064037313848463444",
      "https://x.com/taslimanasreen/status/1854211323053351028?s=19" => "1854211323053351028"
    }.each do |url, expected_id|
      assert_equal expected_id, TwitterMediaSource.send(:extract_tweet_id_from_url, url)
    end
  end

  def test_initializing_returns_blank
    assert_raises(Birdsong::NoTweetFoundError) do
      TwitterMediaSource.extract(Scrape.create({ url: "https://twitter.com/jack/status/1" }))
    end
  end

  # test "can extract tweet without an error being posted to Slack" do
  #   assert_nothing_raised do
  #     tweet = TwitterMediaSource.extract(Scrape.create({ url: "https://twitter.com/Space4Europe/status/1552221138037755904" })) # short video = quick test
  #     assert_not_nil(tweet)
  #   end
  # end

  test "extracted image uploaded to S3" do
    skip unless ENV["AWS_REGION"].present?

    tweets = TwitterMediaSource.extract(Scrape.create({ url: "https://twitter.com/Space4Europe/status/1552221138037755904" }))
    assert_not_nil(tweets)

    tweets.each { |tweet| assert_not_nil(tweet.aws_image_keys) }
  end

  test "tweet has screenshot aws key" do
    skip unless ENV["AWS_REGION"].present?

    tweets = TwitterMediaSource.extract(Scrape.create({ url: "https://twitter.com/Space4Europe/status/1552221138037755904" }))
    assert_not_nil(tweets.first.aws_screenshot_key)

    tweets.each { |tweet| assert_not_nil(tweet.aws_image_keys) }
  end

  test "tweet author has profile image aws key" do
    skip unless ENV["AWS_REGION"].present?

    tweets = TwitterMediaSource.extract(Scrape.create({ url: "https://twitter.com/Space4Europe/status/1552221138037755904" }))
    assert_not_nil(tweets.first.author.aws_profile_image_key)

    tweets.each { |tweet| assert_not_nil(tweet.author.aws_profile_image_key) }
  end

  # test "extracted image is not uploaded to S3 if AWS_REGION isn't set" do
  #   modify_environment_variable("AWS_REGION", nil) do
  #     tweet = TwitterMediaSource.extract(Scrape.create({ url: "https://twitter.com/Space4Europe/status/1552221138037755904" }))
  #     assert_not_nil(tweet)

  #     assert_nil(tweet.first.aws_image_keys)
  #   end
  # end

  test "extracted image uploaded to S3 does not have Base64 in JSON version" do
    skip unless ENV["AWS_REGION"].present?

    tweets = TwitterMediaSource.extract(Scrape.create({ url: "https://twitter.com/Space4Europe/status/1552221138037755904" }))
    assert_not_nil(tweets)

    tweets.each { |tweet| assert_not_nil(tweet.aws_image_keys) }

    json_posts = JSON.parse(PostBlueprint.render(tweets))
    json_posts.each { |tweet| assert_nil tweet["post"]["video_file"] }
  end

  # I don't think this is used anymore'
  # test "extracted image is not uploaded to S3 if AWS_REGION isn't set and does have Base64 in JSON version" do
  #   modify_environment_variable("AWS_REGION", nil) do
  #     tweet = TwitterMediaSource.extract(Scrape.create({ url: "https://twitter.com/Space4Europe/status/1552221138037755904" }))
  #     assert_not_nil(tweet)

  #     assert_nil(tweet.first.aws_image_keys)

  #     tweet = JSON.parse(PostBlueprint.render(tweet.first))
  #     assert_nil tweet["post"]["image_file_key"]
  #   end
  # end

  test "extracted video uploaded to S3" do
    skip unless ENV["AWS_REGION"].present?

    tweets = TwitterMediaSource.extract(Scrape.create({ url: "https://twitter.com/packers/status/1552345663232417801" }))
    assert_not_nil(tweets)

    tweets.each { |tweet| assert_not_nil(tweet.aws_video_keys) }
    tweets.each { |tweet| assert_not_nil(tweet.aws_video_preview_keys) }
  end

  # test "extracted video is not uploaded to S3 if AWS_REGION isn't set" do
  #   modify_environment_variable("AWS_REGION", nil) do
  #     tweet = TwitterMediaSource.extract(Scrape.create({ url: "https://twitter.com/packers/status/1552345663232417801" }))
  #     assert_not_nil(tweet)

  #     assert_nil(tweet.first.aws_video_keys)
  #     assert_nil(tweet.first.aws_video_preview_keys)
  #   end
  # end

  test "extracted video uploaded to S3 does not have Base64 in JSON version" do
    skip unless ENV["AWS_REGION"].present?

    tweets = TwitterMediaSource.extract(Scrape.create({ url: "https://twitter.com/packers/status/1552345663232417801" }))
    assert_not_nil(tweets)

    tweets.each { |tweet| assert_not_nil(tweet.aws_video_keys) }
    tweets.each { |tweet| assert_not_nil(tweet.aws_video_preview_keys) }

    json_posts = JSON.parse(PostBlueprint.render(tweets))
    json_posts.each { |tweet| assert_nil tweet["post"]["video_file"] }
  end

  # test "extracted video is not uploaded to S3 if AWS_REGION isn't set and does have Base64 in JSON version" do
  #   modify_environment_variable("AWS_REGION", nil) do
  #     tweet = TwitterMediaSource.extract(Scrape.create({ url: "https://twitter.com/packers/status/1552345663232417801" }))
  #     assert_not_nil(tweet)

  #     assert_nil(tweet.first.aws_video_keys)

  #     tweet = JSON.parse(PostBlueprint.render(tweet.first))
  #     assert_nil tweet["post"]["video_file_keys"]
  #   end
  # end

  test "twitter user has a username" do
    tweet = TwitterMediaSource.extract(Scrape.create({ url: "https://x.com/WelshLabour/status/1848260101640995243" }))
    assert_not_nil(tweet.first.author.username)
  end

  test "Can handle mixed media posts" do
    tweet = TwitterMediaSource.extract(Scrape.create({ url: "https://x.com/BGatesIsaPyscho/status/1835567947252634020" }))
    assert_not_nil(tweet)
  end

  test "can handle multiple videos" do
    tweet = TwitterMediaSource.extract(Scrape.create({ url: "https://x.com/iam_Chisco1/status/1853732129697415386" }))
    assert_not_nil(tweet)
    # tweet.videos.each { |video| assert_not_nil(video.aws_video_key) }
  end

  test "can handle a different video" do
    tweet = TwitterMediaSource.extract(Scrape.create({ url: "https://x.com/taslimanasreen/status/1854211323053351028?s=19" }))
    assert_not_nil(tweet)

    begin
      tweet.first.aws_video_preview_keys.each do |key|
        AwsObjectUploadFileWrapper.download_file(key, "tmp/birdsong/video_preview.jpg")
        assert File.exist?("tmp/birdsong/video_preview.jpg")
        assert File.size("tmp/birdsong/video_preview.jpg") > 1000
        File.delete("tmp/birdsong/video_preview.jpg") if File.exist?("tmp/birdsong/video_preview.jpg")
      end
    ensure
      File.delete("tmp/birdsong/video_preview.jpg") if File.exist?("tmp/birdsong/video_preview.jpg")
    end
  end

  test "can fail" do
    assert_raises(Birdsong::NoTweetFoundError) do
      TwitterMediaSource.extract(Scrape.create({ url: "https://x.com/alertchannel/status/1853923137106113013" }))
    end
  end
end

# https://x.com/SaadAbedine/status/1831611300356428158/video/1 seems broken, maybe becuase it has a movie and a video?
