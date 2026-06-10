class TwitterPostBlueprint < Blueprinter::Base
  identifier :id

  fields  :id,
          :text,
          :language,
          :created_at

  association :author, blueprint: TwitterUserBlueprint

  field :object_type do |tweet|
    "twitter"
  end

  field :image_files do |tweet|
    to_return = nil
    if tweet.images.nil? == false && tweet.aws_image_keys.blank?
      to_return = tweet.images.map do |file_name|
        base64_temp = nil
        File.open(file_name) { |file| base64_temp = Base64.encode64(file.read) }
        base64_temp
      end
    end

    to_return
  end

  field :video_files do |tweet|
    to_return = nil
    if tweet.videos.empty? == false && tweet.aws_video_keys.blank?
      base64_temp = nil
      File.open(tweet.videos.first) { |file| base64_temp = Base64.encode64(file.read) }
      base64_temp
    end

    to_return
  end

  # This isn't used anymore I believe
  field :video_preview_images do |tweet|
    to_return = nil
    if tweet.videos.empty? == false && tweet.aws_video_preview_keys.blank?
      base64_temp = nil
      File.open(tweet.video_preview_images) { |file| base64_temp = Base64.encode64(file.read) }
      base64_temp
    end

    to_return
  end

  # This isn't used anymore I believe
  field :screenshot_file do |tweet|
    if tweet.screenshot_file.present? && tweet.aws_screenshot_key.blank?
      base64_temp = nil
      File.open(tweet.screenshot_file) { |file| base64_temp = Base64.encode64(file.read) }
      base64_temp
    end
  end

  field :aws_video_keys do |tweet|
    tweet.aws_video_keys()
  end

  field :aws_video_preview_keys do |tweet|
    tweet.aws_video_preview_keys()
  end

  field :aws_image_keys do |tweet|
    tweet.aws_image_keys()
  end

  field :aws_screenshot_key do |tweet|
    tweet.aws_screenshot_key()
  end
end
