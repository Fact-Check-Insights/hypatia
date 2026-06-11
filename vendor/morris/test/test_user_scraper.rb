# frozen_string_literal: true

require "test_helper"

class UserScraperTest < Minitest::Test
  i_suck_and_my_tests_are_order_dependent!()

  def teardown
    cleanup_temp_folder
  end

  def test_scraping_a_user_page_works
    result = Morris::PostScraper.new.parse("https://www.tiktok.com/@guess/video/7091753416032128299")
    assert_not_nil(result)

    assert_not_nil(result[:video])
    assert_not_nil(result[:video_preview_image])
    assert_not_nil(result[:screenshot_file])
    assert_not_nil(result[:text])
    assert_not_nil(result[:date])
    assert_not_nil(result[:number_of_likes])
    assert_not_nil(result[:user])
    assert_not_nil(result[:id])

    assert_equal "76% of Americans are 1 Paycheck from Poverty #paycheck #cryptoqueen #money #mindset #homebasedbusiness", result[:text]
    assert_equal Time.at(1651177513), result[:date]
    assert result[:number_of_likes] > 1
    assert_equal "7091753416032128299", result[:id]
  end
end
