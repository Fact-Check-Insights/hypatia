## [Unreleased]

## [0.3.0] - 2026-06-12

- Add an Antena REST API bypass. When `ANTENA_TOKEN` is set, `Zorki::Post.lookup` fetches
  posts from the Antena API (`ANTENA_BASE_ENDPOINT`) instead of scraping Instagram with a
  browser, returning the same post/user object schema. Photo, carousel, video and poster
  media are downloaded from Antena's object storage (`s3_url`/`poster_s3_url`), never from
  the expiring Instagram platform urls.

## [0.1.0] - 2021-04-28

- Initial release
