## [Unreleased]

## [0.2.0] - 2026-06-11

- Add an Antena REST API bypass. When `ANTENA_TOKEN` is set, `Morris::Post.lookup` fetches
  posts from the Antena API (`ANTENA_BASE_ENDPOINT`) instead of scraping TikTok with a
  browser, returning the same post/user hash schema. Video and poster media are downloaded
  from Antena's object storage (`s3_url`/`poster_s3_url`), never from the expiring TikTok
  platform urls.

## [0.1.0] - 2024-02-19

- Initial release
