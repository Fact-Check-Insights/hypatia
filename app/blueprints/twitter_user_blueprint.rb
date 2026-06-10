class TwitterUserBlueprint < Blueprinter::Base
  identifier :username

  fields  :name,
          :username,
          :id,
          :created_at,
          :description,
          :url,
          :profile_image_url,
          :location,
          :followers_count,
          :following_count,
          :aws_profile_image_key

  field :profile_image do |user|
    to_return = nil
    if user.profile_image_file_name.present? && user.aws_profile_image_key.blank?
      File.open(user.profile_image_file_name) { |file| to_return = Base64.encode64(file.read) }
    end

    to_return
  end
end
