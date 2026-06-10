# frozen_string_literal: true

require "test_helper"
require "date"

class TweetScraperTest < Minitest::Test
  def teardown
    cleanup_temp_folder
  end

  # def test_scraper
  #   Birdsong::TweetScraper.new.parse("1407342630837657605")
  # end
end
