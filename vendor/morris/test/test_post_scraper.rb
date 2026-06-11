# frozen_string_literal: true

require "test_helper"

class PostScraperTest < Minitest::Test
  i_suck_and_my_tests_are_order_dependent!()

  def teardown
    cleanup_temp_folder
  end

  def test_scraping_a_post_page_works
    result = Morris::UserScraper.new.lookup("queene11even")
    assert_not_nil(result)

    #  name: name,
    #  username: username,
    #  number_of_posts: number_of_posts,
    #  number_of_followers: number_of_followers,
    #  number_of_following: number_of_following,
    #  verified: verified,
    #  profile: profile,
    #  profile_link: profile_link,
    #  profile_image: profile_image,
    #  profile_image_url: profile_image_url

    assert_equal "QUEENE11EVEN♟️💰", result[:name]
    assert_equal "queene11even", result[:username]
    assert result[:number_of_posts] > 1
    assert result[:number_of_followers] > 1
    assert result[:number_of_following] > 1
    assert_equal false, result[:verified]
    assert_equal "👑 I Build Leaders Who Make Crypto & Cashflow Moves♟💰💸👸🏽", result[:profile]
    assert_equal "https://www.tiktok.com/@queene11even", result[:profile_link]
    assert_not_nil(result[:profile_image])
    assert_not_nil(result[:profile_image_url])
  end
end
