# frozen_string_literal: true

require "test_helper"

class VideoTest < Minitest::Test
  i_suck_and_my_tests_are_order_dependent!()

  def teardown
    cleanup_temp_folder
  end

  def test_scraping_a_post_page_works
    result = Morris::VideoScraper.lookup("https://www.tiktok.com/@guess/video/7091753416032128299")
    assert_not_nil(result)
    assert File.exist?(result) # Assert it's actually downloaded and all that
    assert File.size(result) > 500000 # Make sure it's the right file we're checking
  end
end
