Figaro.require_keys("SECRET_KEY_BASE")

Figaro.require_keys("INSTAGRAM_USER_NAME", "INSTAGRAM_PASSWORD")
Figaro.require_keys("FACEBOOK_EMAIL", "FACEBOOK_PASSWORD")
Figaro.require_keys("TWITTER_USER_NAME", "TWITTER_PASSWORD")
Figaro.require_keys("NITTER_URL")
Figaro.require_keys("GRIGORI_CALLBACK_URL")
Figaro.require_keys("HOST")

# Hypatia can be configured two ways:
# 1. Send anything scraped directly to a Zenodotus instance (or anything conforming to the API)
# 2. Upload scraped media to AWS S3 (or any system with S3 compatible APIs such as CloudFlare's R2) and pass over a link to the media in the Zeno API Call
#
# If AWS_REGION isn't set it'll choose #1 automatically, otherwise we'll fall back to #2
# Note that Zenodotus can handle either and is 100% agnostic (unless it can't find the AWS file, then it yells)
unless Figaro.env.AWS_REGION.blank?
  Figaro.require_keys("AWS_REGION", "S3_ENDPOINT", "AWS_S3_BUCKET_NAME", "AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY")
  ENV["AWS_S3_PATH"] = "" if Figaro.env.AWS_S3_PATH.nil?
end

# Other optional environment variables:
#
# SLACK_ERROR_WEBHOOK_URL
# ---
# When set this will enable the reporting of scraping errors to a Slack channel.
# To set up you can create an "Incoming Webhook" at https://api.slack.com/apps
# and put the url in this environment variable.
#
# AWS_S3_PATH
# ---
# When set this will put any files uploaded to S3 to the subdirectory indicated.
# Make sure it ends in a `/` otherwise the last folder will just be a prefix instead.
