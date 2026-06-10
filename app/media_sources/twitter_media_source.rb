class TwitterMediaSource < MediaSource
  include Birdsong
  attr_reader(:url)

  # A string to indicate what type of scraper this model is for
  #
  # @return [String] the canonical name for the type this scraper handles
  def self.model_type
    "twitter"
  end

  # Limit all urls to the host below
  #
  # @return [String] or [Array] of [String] of valid host names
  def self.valid_host_name
    ["www.twitter.com", "twitter.com", "mobile.twitter.com", "www.x.com", "x.com", "mobile.x.com"]
  end

  # Capture a screenshot of the given url
  #
  # @!scope class
  # @params url [String] the url of the page to be collected for archiving
  # @params save_screenshot [Boolean] whether to save the screenshot image (mostly for testing).
  #   Default: false
  # @returns [String or nil] the path of the screenshot if the screenshot was saved
  def self.extract(scrape, save_screenshot = false)
    object = self.new(scrape.url)
    object.retrieve_tweet
  rescue Birdsong::NoTweetFoundError => e
    message = "Twitter post #{scrape.url} is unavailable"
    @@logger.error message
    self.send_message_to_slack(message)
    raise e
  end

  # Initialize the object and capture the screenshot automatically.
  #
  # @params url [String] the url of the page to be collected for archiving
  # @returns [Sting or nil] the path of the screenshot if the screenshot was saved
  def initialize(url)
    # Verify that the url has the proper host for this source. (@valid_host is set at the top of
    # this class)
    TwitterMediaSource.check_url(url)
    TwitterMediaSource.validate_tweet_url(url)

    @url = url
  end

  # Call the Twitter API using the Birdsong gem and get an object
  #
  # @!visibility private
  # @params url [String] a url to grab data for
  # @return [Birdson::Tweet]
  def retrieve_tweet
    id = TwitterMediaSource.extract_tweet_id_from_url(@url)
    tweet = Birdsong::Tweet.lookup(id).first

    self.class.create_aws_key_functions_for_posts([tweet])

    return [tweet] unless s3_transfer_enabled?

    # Upload user profile picture to s3
    if tweet.author.profile_image_file_name.present?
      @@logger.debug "Uploading user profile picture #{tweet.author.profile_image_file_name}"
      aws_upload_wrapper = AwsObjectUploadFileWrapper.new(tweet.author.profile_image_file_name)
      aws_upload_wrapper.upload_file
      tweet.author.instance_variable_set("@aws_profile_image_key", aws_upload_wrapper.object.key)
    end

    # Upload tweet screenshot to s3
    if tweet.screenshot_file.present?
      @@logger.debug "Uploading tweet screenshot #{tweet.screenshot_file}"
      aws_upload_wrapper = AwsObjectUploadFileWrapper.new(tweet.screenshot_file)
      aws_upload_wrapper.upload_file
      tweet.instance_variable_set("@aws_screenshot_key", aws_upload_wrapper.object.key)
    end

    @@logger.debug "Beginning uploading of files to S3 bucket #{Figaro.env.AWS_S3_BUCKET_NAME}"
    # Let's see if it's a video or images, and upload them
    if tweet.images.present?
      aws_image_keys = tweet.images.map do |image_file_name|
        @@logger.debug "Uploading image #{image_file_name}"
        aws_upload_wrapper = AwsObjectUploadFileWrapper.new(image_file_name)
        aws_upload_wrapper.upload_file
        aws_upload_wrapper.object.key
      end

      tweet.instance_variable_set("@aws_image_keys", aws_image_keys)
    end

    if tweet.videos.present?
      video_file_keys = []
      video_file_preview_keys = []

      tweet.videos.each_with_index do |video_file_name, index|
        video_file_name = video_file_name.first if video_file_name.first.is_a?(Array) # To fix some structure stuff

        @@logger.debug "Uploading video #{video_file_name}"
        aws_upload_wrapper = AwsObjectUploadFileWrapper.new(video_file_name)
        aws_upload_wrapper.upload_file
        video_file_keys << aws_upload_wrapper.object.key

        # We we add multiple videos we'll have to fix up Birdsong to group these, for now this will work
        @@logger.debug "Uploading video preview #{tweet.video_preview_images[index]}"
        aws_upload_wrapper = AwsObjectUploadFileWrapper.new(tweet.video_preview_images[index])
        aws_upload_wrapper.upload_file
        video_file_preview_keys << aws_upload_wrapper.object.key
      end

      tweet.instance_variable_set("@aws_video_keys", video_file_keys)
      tweet.instance_variable_set("@aws_video_preview_keys", video_file_preview_keys)
    end

    [tweet]
  end

  # Checks if a URL is supported by this scraper
  #
  # @params url [String] a url to check for compatibility on
  # @return [Boolean] whether the url is supported or not
  def self.can_handle_url?(url)
    TwitterMediaSource.send(:validate_tweet_url, url)
  rescue TwitterMediaSource::InvalidTweetUrlError
    false
  end

private

  # Validate that the url is a direct link to a tweet, poorly
  #
  # @note this assumes a valid url or else it'll always (usually, maybe, whatever) fail
  #
  # @!scope class
  # @!visibility private
  # @params url [String] a url to check if it's a valid Twitter tweet url
  # @return [Boolean] if the string validates or not
  def self.validate_tweet_url(url)
    self.valid_host_name.each do |host_name|
      return true if /#{host_name}\/[\w]+\/[\w]+\/[0-9]+/.match?(url)
    end
    raise TwitterMediaSource::InvalidTweetUrlError, "Tweet url #{url} does not have the standard url format"
  end

  # Grab the ID from the end of a twitter URL
  #
  # @note this assumes a valid url or else it'll return weird stuff
  # @!scope class
  # @!visibility private
  # @params url [String] a url to extract an id from
  # @return [String] the id from the url or [Nil]
  def self.extract_tweet_id_from_url(url)
    # Tweet urls can carry trailing segments like /photo/1 or /video/1 (and query
    # strings), so we can't just take the last path component. Grab the numeric id
    # that immediately follows /status/.
    match = url.match(%r{/status/(\d+)})
    raise TwitterMediaSource::InvalidTweetUrlError if match.nil?

    match[1]
  end
end

# A class to indicate that a tweet url passed in is invalid
class TwitterMediaSource::InvalidTweetUrlError < StandardError; end
