require "sidekiq/api"

class ScrapeJob < ApplicationJob
  # sidekiq_options retry: 10
  queue_as :default

  retry_on Birdsong::RateLimitExceeded, wait: 400.seconds, jitter: 0.30, attempts: 10 do
    Honeybadger.notify(e, context: { url: url, status: "rate_limit_exceeded" })
  end

  retry_on Zorki::RetryableError, Forki::RetryableError, YoutubeArchiver::RetryableError, wait: 30.seconds, jitter: 0.30, attempts: 3 do |job, error|
    url = job.arguments.first
    callback_id = job.arguments.length > 1 ? job.arguments[1] : nil

    logger.info "Errored retries on #{job.arguments.first} with #{error}"
    CommsManager.send_scrape_status_update(ENV["VM_NAME"], 302, { url: url, scrape_id: callback_id, message: e.full_message(highlight: true) })
  end

  retry_on Zorki::ContentUnavailableError, wait: 30.seconds, jitter: 0.30, attempts: 3 do |job, error|
    url = job.arguments.first
    callback_id = job.arguments.length > 1 ? job.arguments[1] : nil
    CommsManager.send_scrape_status_update(ENV["VM_NAME"], 303, { url: url, scrape_id: callback_id })
    logger.info "\nPost removed at: #{url}\n"
    Honeybadger.notify(error, context: { url: url, status: "removed" })
  end

  retry_on Birdsong::NoTweetFoundError, wait: 30.seconds, jitter: 0.30, attempts: 3 do |job, error|
    url = job.arguments.first
    callback_id = job.arguments.length > 1 ? job.arguments[1] : nil
    CommsManager.send_scrape_status_update(ENV["VM_NAME"], 303, { url: url, scrape_id: callback_id })

    logger.info "\nPost removed at: #{url}\n"

    Honeybadger.notify(error, context: { url: url, status: "removed" })
  end

  sidekiq_retries_exhausted do |message, error|
    logger.error "Exhausted retries trying to scrape url #{message['arguments'].first}. Error: #{error}"
    Typhoeus.post("#{Figaro.env.GRIGORI_CALLBACK_URL}/archive/scrape_result_callback",
                  headers: { "Content-Type": "application/json" },
                  body: { scrape_id: callback_id, scrape_result: "[]" })
  end

  def perform(url, callback_id = nil)
    # If there's no callback id or the callback url isn't set, then ignore this
    # Otherwise, send it back to the source

    # We need to wait a certain amount of time to stop being caught
    wait_time = ScrapeJob.get_correct_period_of_wait_time(url)
    sleep(wait_time) if !wait_time.nil? && wait_time.positive?

    results = MediaSource.scrape!(url, callback_id)

    logger.info "\nFinished scraping #{url}\n"
    logger.info "\n********************\n"
    logger.info "Sending callback to #{Figaro.env.GRIGORI_CALLBACK_URL}\n"
    logger.info "\n********************\n"

    # raise "Nil returned from scraping ÷for #{url}" if results.nil?
    CommsManager.send_scrape_status_update(ENV["VM_NAME"], 203, { url: url, scrape_id: callback_id, result: PostBlueprint.render(results) })

    # params = { scrape_id: callback_id, scrape_result: PostBlueprint.render(results) }

    # Typhoeus.post("#{Figaro.env.GRIGORI_CALLBACK_URL}/archive/scrape_result_callback",
    #     headers: { "Content-Type": "application/json" },
    #     body: params.to_json)
  rescue Zorki::RetryableError, Forki::RetryableError, YoutubeArchiver::RetryableError => e
    # We catch and reraise here to just have a point where we can intervene if necessary
    raise e
  rescue Zorki::ContentUnavailableError, Forki::ContentUnavailableError, YoutubeArchiver::VideoNotFoundError,
          YoutubeArchiver::ChannelNotFoundError, Morris::ContentUnavailableError => e
    # This means the content has been taken down before we could get to it.
    # Here we do a callback but with a notification the content is removed

    CommsManager.send_scrape_status_update(ENV["VM_NAME"], 303, { url: url, scrape_id: callback_id })

    logger.info "\nPost removed at: #{url}\n"

    Honeybadger.notify(e, context: { url: url, status: "removed" })
  rescue Forki::PostExtractionError => e
    # Forki reached the post but couldn't extract its data. This is NOT a
    # removed post — it usually signals a Facebook layout change or a post
    # shape Forki doesn't handle yet. Report it as an error (302) so it gets
    # investigated, instead of silently marking the post as removed (303).
    CommsManager.send_scrape_status_update(ENV["VM_NAME"], 302, { url: url, scrape_id: callback_id })

    logger.error "\nPost extraction failed at: #{url} — #{e.message}\n"

    Honeybadger.notify(e, context: { url: url, status: "parse_error" })
  rescue MediaSource::HostError => e
    # This means the content can't be scraped, which is not good. However, we don't want to keep retrying
    # so we send an error back to Zenodotus
    CommsManager.send_scrape_status_update(ENV["VM_NAME"], 302, { url: url, scrape_id: callback_id })

    logger.error "\nPost parsing error at: #{url}\n"

    Honeybadger.notify(e, context: { url: url, status: "error" })
  rescue StandardError => e # If we run into an error retries can't fix, don't retry the job
    # We don't want errors to ruin everything so we'll catch everything
    raise e if e.is_a?(Birdsong::NoTweetFoundError) # We're going to eventually handle all this up there
    logger.fatal "*************************************************************"
    logger.fatal "Error During Scraping"
    logger.fatal "Type: #{e.class.name}"
    logger.fatal "Timestamp: #{Time.now}"
    logger.fatal "Status: Unrecoverable"
    logger.fatal "URL: #{url}"
    logger.fatal "Message: #{e.full_message(highlight: true)}"
    logger.fatal "*************************************************************"
    Honeybadger.notify(e, context: { url: url, status: "unknown" })

    CommsManager.send_scrape_status_update(ENV["VM_NAME"], 302, { url: url, scrape_id: callback_id, message: e.full_message(highlight: true) })
  end

  def self.get_correct_period_of_wait_time(url)
    # Only sleep for the services we need to
    # Facebook: Yes
    # Instagram: Yes
    # Twitter: No, uses an API
    # YouTube: No, uses downloader
    # TikTok: No, doesn't seem to have a rate limit

    # Note: we should really do queues and skip around to prioritize the density, if we ever need it
    media_source = MediaSource.model_for_url(url)

    # Seems that you can't compare classes in a case statement
    if media_source == FacebookMediaSource
      key = :facebook
    elsif media_source == InstagramMediaSource
      key = :instagram
    else
      return 0 # Unless it's Facebook or Instagram we don't wait at all
    end

    # This is probably too convoluted, but it works!
    sleep_time = rand(Setting.scrape_wait_time_range[key]) * 60
    last_time = Setting.last_scrape_time[key]
    Setting.last_scrape_time[key] = Time.now

    # If we haven't set it up yet
    return 0 if last_time.nil?

    time_difference = Time.now - last_time
    return 0 if time_difference > sleep_time # we're good to go

    # Wait the difference in Time
    logger.info "Sleeping #{time_difference} seconds to hopefully prevent scraping bots from noticing us."
    puts time_difference
    time_difference
  end
end
