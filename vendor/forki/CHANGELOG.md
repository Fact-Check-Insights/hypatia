## [Unreleased]

## [0.3.0] - 2026-06-16

- Add an Antena REST API bypass. When `ANTENA_TOKEN` is set, `Forki::Post.lookup` fetches
  posts from the Antena API (`ANTENA_BASE_ENDPOINT`) instead of scraping Facebook with a
  browser, returning the same post/user object schema. Photo, video and poster media are
  downloaded from Antena's object storage (`s3_url`/`poster_s3_url`), never from the expiring
  Facebook platform urls. `created_at` is converted to a Unix timestamp (as the browser
  scraper returned) and all fields are defensively coerced against Antena nulls.

## [0.1.0] - 2021-04-28

- Initial release
