## [Unreleased]

## [0.3.0] - 2026-06-10

- Added an Antena REST API client. When the `ANTENA_TOKEN` env var is present, `Birdsong::Tweet.lookup`
  bypasses the browser scraper and fetches tweets from the Antena API (base url from `ANTENA_BASE_ENDPOINT`),
  returning the same data schema. Falls back to the Selenium scraper when no token is set.

## [0.1.0] - 2021-04-27

- Initial release

## [0.2.0] - 2023-10-04

- Fixed to use Selenium for scraping instead of the now defunct API
