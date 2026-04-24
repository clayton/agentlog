# Changelog

## [0.9.0] - 2026-04-24

- Initial public release candidate.
- Added a Railtie-backed secondary logger for Rails `development` and `test`.
- Added compact `REQ` request summaries with db, view, and gc timings.
- Added grouped `SQL` summaries for repeated and slow queries.
- Added compact `JOB` enqueue summaries during requests.
- Added configurable scalar preservation via `preserve_keys`.
