# frozen_string_literal: true

require "typhoeus"

module Morris
  class PostScraper < Scraper
    def parse(url)
      # Stuff we need to get from the DOM (implemented is starred):
      # - User *
      # - Text *
      # - Image * / Images * / Video *
      # - Date *
      # - Number of likes *
      # - Hashtags

      Capybara.app_host = "https://tiktok.com"

      # Clean up the url
      uri = URI.parse(url)

      url = "#{uri.scheme}://#{uri.host}#{uri.path}"

      # Get the page
      begin
        visit(url)
      rescue Addressable::URI::InvalidURIError
        raise Morris::ContentUnavailableError.new
      end

      # Grab the JSON
      element = page.all(:xpath, '//*[@id="__UNIVERSAL_DATA_FOR_REHYDRATION__"]', visible: false).first

      # If the element is not found, raise a ContentUnavailableError
      if element.nil?
        begin
          page.find(class: "not-found")
        rescue Capybara::ElementNotFound
          raise Morris::ContentUnavailableError.new
        end
      end

      text = element.text(:all) # Gotta get the hiddent text of the element
      json = JSON.parse(text)

      content_element = json["__DEFAULT_SCOPE__"]["webapp.video-detail"]["itemInfo"]["itemStruct"]

      id = content_element["id"]
      text = content_element["desc"]
      number_of_likes = content_element["stats"]["diggCount"]
      date = Time.at(content_element["createTime"].to_i)
      video_preview_image = Morris.retrieve_media(content_element["video"]["cover"])
      video = Morris::VideoScraper.lookup(url)
      username = content_element["author"]["uniqueId"]

      screenshot_file = take_screenshot()

      # This has to run last since it switches pages
      user = Morris::UserScraper.new.lookup(username)

      {
        video: video,
        video_preview_image: video_preview_image,
        screenshot_file: screenshot_file,
        text: text,
        date: date,
        number_of_likes: number_of_likes,
        user: user,
        id: id
      }
    end

    def take_screenshot
      # First check if a post has a fact check overlay, if so, clear it.
      # The only issue is that this can take *awhile* to search. Not sure what to do about that
      # since it's Instagram's fault for having such a fucked up obfuscated hierarchy
      begin
        find_button("See Post").click
        sleep(0.1)
      rescue Capybara::ElementNotFound
        # Do nothing if the element is not found
      end

      # Take the screenshot and return it
      save_screenshot("#{Morris.temp_storage_location}/instagram_screenshot_#{SecureRandom.uuid}.png")
    end
  end
end
