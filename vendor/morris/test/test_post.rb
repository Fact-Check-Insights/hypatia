# frozen_string_literal: true

require "test_helper"

class PostTest < Minitest::Test
  i_suck_and_my_tests_are_order_dependent!()

  def teardown
    cleanup_temp_folder
  end

  # Note: if this fails, check the account, the number may just have changed
  # We're using Pete Souza because Obama's former photographer isn't likely to be taken down
  def test_a_post_returns_properly_when_scraped
    post = Morris::Post.lookup(["https://www.tiktok.com/@davidjustinn/video/6964137078095482117?_d=secCgYIASAHKAESMgowOz9UzOejaM6f2tH9b%2BQNWLTqzHRhqkQyZ4Nc%2FS9KBxiUubZzbaLh7bysh%2BXpUa44GgA%3D&_r=1&checksum=22612f4ab971d32b5d70ce580477377f982dd0b5e730a543ecc79d7c51c229fc&is_copy_url=1&is_from_webapp=v1&language=en&preview_pb=0&sec_user_id=MS4wLjABAAAAr6uRci2OS6T-EjEqVBxSJa6IusrYe9pcSQKQndLwxcCrPeZCZ7V48eHi3zcBvM2V&share_app_id=1233&share_item_id=6964137078095482117&share_link_id=3525F675-80CC-41C3-B12F-DCA726D6FCCF&source=h5_m&timestamp=1622474842&tt_from=copy&u_code=dbeci7ah72ce4k&user_id=6807403034207093765&utm_campaign=client_share&utm_medium=ios&utm_source=copy"]).first
    assert_not_nil post.video_file_name
    assert_not_nil post.video_preview_image
    assert_not_nil post.screenshot_file
  end

  def test_a_video_post_properly_downloads_video
    post = Morris::Post.lookup(["https://www.tiktok.com/@davidjustinn/video/6964137078095482117?_d=secCgYIASAHKAESMgowOz9UzOejaM6f2tH9b%2BQNWLTqzHRhqkQyZ4Nc%2FS9KBxiUubZzbaLh7bysh%2BXpUa44GgA%3D&_r=1&checksum=22612f4ab971d32b5d70ce580477377f982dd0b5e730a543ecc79d7c51c229fc&is_copy_url=1&is_from_webapp=v1&language=en&preview_pb=0&sec_user_id=MS4wLjABAAAAr6uRci2OS6T-EjEqVBxSJa6IusrYe9pcSQKQndLwxcCrPeZCZ7V48eHi3zcBvM2V&share_app_id=1233&share_item_id=6964137078095482117&share_link_id=3525F675-80CC-41C3-B12F-DCA726D6FCCF&source=h5_m&timestamp=1622474842&tt_from=copy&u_code=dbeci7ah72ce4k&user_id=6807403034207093765&utm_campaign=client_share&utm_medium=ios&utm_source=copy"]).first
    assert !post.video_file_name.start_with?("https://")
  end

  def test_a_post_has_been_removed
    assert_raises Morris::ContentUnavailableError do
      Morris::Post.lookup(["sfhslsfjdls"])
    end
  end
end
