# frozen_string_literal: true

module Forki
  class User
    def self.lookup(urls = [])
      urls = [urls] unless urls.kind_of?(Array)
      self.scrape(urls)
    end

    # Builds a User from the actor data embedded in a post's GraphQL.
    # Used as a fallback when the poster's profile page can't be scraped
    # (for instance group posts, whose actor URL doesn't resolve to a
    # standard profile). Only the fields present in the post are populated.
    #
    # @param actor [Hash, nil] the actor object lifted from a post
    # @return [Forki::User, nil] a partial user, or nil if there's no actor
    def self.from_actor(actor)
      return nil unless actor.is_a?(Hash)
      return nil if actor["name"].nil? && actor["id"].nil?

      # Group posts often expose the actor without a URL. The numeric id is
      # itself a valid canonical profile URL, so derive one when it's missing.
      profile_link = actor["url"]
      profile_link ||= "https://www.facebook.com/#{actor["id"]}" unless actor["id"].nil?

      new(
        name: actor["name"],
        id: actor["id"],
        profile_link: profile_link
      )
    end

    attr_reader :name,
                :id,
                :number_of_followers,
                :verified,
                :profile,
                :profile_link,
                :profile_image_file,
                :profile_image_url,
                :number_of_likes

    private

      def initialize(user_hash = {})
        @name = user_hash[:name]
        @id = user_hash[:id]
        @number_of_followers = user_hash[:number_of_followers]
        @verified = user_hash[:verified]
        @profile = user_hash[:profile]
        @profile_link = user_hash[:profile_link]
        @profile_image_file = user_hash[:profile_image_file]
        @profile_image_url = user_hash[:profile_image_url]
        @number_of_likes = user_hash[:number_of_likes]
      end

      class << self
        private

          def scrape(urls)
            urls.map do |url|
              user_hash = Forki::UserScraper.new.parse(url)
              User.new(user_hash) if user_hash.is_a?(Hash)
            end
          end
      end
  end
end
