class InstagramPostBlueprint < Blueprinter::Base
  identifier :id

  fields  :id,
          :text,
          :date,
          :number_of_likes

  association :user, blueprint: InstagramUserBlueprint

  field :object_type do |post|
    "instagram"
  end

  field :image_files do |post|
    to_return = nil
    if post.image_file_names.nil? == false && post.aws_image_keys.blank?
      to_return = post.image_file_names.map do |file_name|
        base64_temp = nil
        File.open(file_name) { |file| base64_temp = Base64.encode64(file.read) }
        base64_temp
      end
    end

    to_return
  end

  # field :video_file do |post|
  #   to_return = nil
  #   if post.video_file_name.nil? == false && post.aws_video_key.blank?
  #     File.open(post.video_file_name) { |file| to_return = Base64.encode64(file.read) }
  #   end

  #   to_return
  # end


  # field :video_preview_image do |post|
  #   to_return = nil
  #   if post.video_preview_image.nil? == false && post.aws_video_preview_key.blank?
  #     File.open(post.video_preview_image) { |file| to_return = Base64.encode64(file.read) }
  #   end

  #   to_return
  # end

  field :screenshot_file do |post|
    to_return = nil
    if post.screenshot_file.present? && post.aws_screenshot_key.blank?
      File.open(post.screenshot_file) { |file| to_return = Base64.encode64(file.read) }
    end

    to_return
  end

  field :aws_video_key do |post|
    post.aws_video_key()
  end

  field :aws_video_preview_key do |post|
    post.aws_video_preview_key()
  end

  field :aws_image_keys do |post|
    post.aws_image_keys()
  end

  field :aws_screenshot_key do |post|
    post.aws_screenshot_key()
  end
end
