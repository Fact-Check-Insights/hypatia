# # frozen_string_literal: true

# require "test_helper"
# require "date"

# class UserTest < Minitest::Test
#   def teardown
#     cleanup_temp_folder
#   end

#   def test_that_a_user_is_created_with_id
#     tweets = Birdsong::User.lookup("404661154")
#     tweets.each { |user| assert_instance_of Birdsong::User, user }
#   end

#   def test_that_a_user_raises_exception_with_invalid_id
#     assert_raises Birdsong::InvalidIdError do
#       Birdsong::User.lookup("abcdef")
#     end
#   end

#   # This could break if Frederik ever changes his info. That's probably the reason if this is failing
#   def test_that_a_tweet_has_correct_attributes
#     user = Birdsong::User.lookup("404661154").first
#     assert_equal "404661154", user.id
#     assert_equal DateTime.parse("2011-11-04T07:18:35.000Z"), user.created_at
#     assert_equal "http://pbs.twimg.com/profile_images/1140973306889277440/q3P0CIh6.jpg", user.profile_image_url
#     assert_equal "Frederik Obermaier", user.name
#     assert_equal "f_obermaier", user.username
#     assert_equal "Threema FPN4FKZE  | PGP", user.location
#     assert user.description.include? "journalist"
#     assert_equal "http://www.frederikobermaier.com", user.url
#     assert_kind_of Integer, user.followers_count
#     assert_kind_of Integer, user.following_count
#     assert_kind_of Integer, user.tweet_count
#     assert_kind_of Integer, user.listed_count
#     assert user.verified == false
#     assert user.profile_image_file_name.empty? == false

#     # Make sure the file is created properly
#     assert File.exist?(user.profile_image_file_name) && File.file?(user.profile_image_file_name)
#   end

#   # `verified` is always false since the weird Musk decisions, so we're going to comment this out
#   # def test_that_a_verified_user_is_probably_marked
#   #   user = Birdsong::User.lookup_by_usernames("Alphafox78").first
#   #   assert user.verified
#   # end
# end
