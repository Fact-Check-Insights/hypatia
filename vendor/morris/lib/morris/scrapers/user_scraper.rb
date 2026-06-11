# frozen_string_literal: true

require "typhoeus"

module Morris
  class UserScraper < Scraper
    def lookup(username)
      Capybara.app_host = "https://tiktok.com"
      url = "https://www.tiktok.com/@#{username}"

      # Get the page
      visit(url)

      # Grab the JSON
      element = page.all(:xpath, '//*[@id="__UNIVERSAL_DATA_FOR_REHYDRATION__"]', visible: false).first
      text = element.text(:all) # Gotta get the hiddent text of the element
      json = JSON.parse(text)

      content_element = json["__DEFAULT_SCOPE__"]["webapp.user-detail"]["userInfo"]

      name = content_element["user"]["nickname"]
      username = content_element["user"]["uniqueId"]
      number_of_posts = content_element["stats"]["videoCount"]
      number_of_followers = content_element["stats"]["followerCount"]
      number_of_following = content_element["stats"]["followingCount"]
      verified = content_element["user"]["verified"]
      profile = content_element["user"]["signature"]
      profile_link = url
      profile_image = Morris.retrieve_media(content_element["user"]["avatarLarger"])
      profile_image_url = content_element["user"]["avatarLarger"]

      {
        name: name,
        username: username,
        number_of_posts: number_of_posts,
        number_of_followers: number_of_followers,
        number_of_following: number_of_following,
        verified: verified,
        profile: profile,
        profile_link: profile_link,
        profile_image: profile_image,
        profile_image_url: profile_image_url
      }
    end
  end
end
