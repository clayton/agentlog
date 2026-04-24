# Agentlog

Agentlog is a Rails gem that adds a second development/test log optimized for coding agents.

It does not replace `log/development.log`. It writes a separate compact log that preserves the important request story while aggressively shrinking token-heavy details like params, job args, and repetitive SQL noise.

## What It Logs

- One compact `REQ` line per controller request
- Optional grouped `SQL` lines for repeated or slow queries
- Optional `JOB` lines for enqueues that happen during the request
- Optional `ERR` lines when the request raises

By default it:

- writes to `log/agent.log`
- enables itself only in `development` and `test`
- keeps params on, but reduces values to type and size markers
- hides scalar values unless you explicitly preserve specific keys
- ignores arbitrary app log lines

## Installation

Add the gem to your Rails app:

```ruby
gem "agentlog"
```

Then bundle:

```bash
bundle install
```

## Configuration

Agentlog auto-installs through a Railtie in `development` and `test`.

You can override defaults in an initializer:

```ruby
# config/initializers/agentlog.rb
Rails.application.config.agentlog.enabled = Rails.env.development? || Rails.env.test?
Rails.application.config.agentlog.path = "log/agent.log"
Rails.application.config.agentlog.log_params = true
Rails.application.config.agentlog.log_sql = true
Rails.application.config.agentlog.log_jobs = true
Rails.application.config.agentlog.preserve_keys = %w[user_id task_id request_id]
Rails.application.config.agentlog.repeat_sql_threshold = 3
Rails.application.config.agentlog.slow_sql_ms = 25.0
```

## Example Output

```text
10:48:01 REQ POST /api/v1/app_events -> 202 8.0ms ctrl=api/v1/app_events#create fmt=json params={events:[{platform:str(3),app_version:str(3),session_id:str(36),event_name:str(12),properties:{active_task_count:int,variant:str(6)},+2} x8],device_id:str(36),app_event:{device_id:str(36)}} db=3.4ms/4q view=0.1ms gc=0.0ms
10:48:01 SQL NotificationToken_Load x3 1.5ms
10:48:01 JOB enqueue IngestAppEventsJob queue=default args=["E12AB6BE-8CB7-48A8-9972-1F52DD56C527",[{platform:str(3),app_version:str(3),session_id:str(36),event_name:str(39),properties:{error:str(142)},+1} x8],4239]
```

## Preserving Specific IDs

If you want a few debugging IDs to stay visible, list their keys in `preserve_keys`.

```ruby
Rails.application.config.agentlog.preserve_keys = %w[user_id device_id task_id]
```

That changes values for those keys from compact markers like `str(36)` to truncated literals.

## Scope

`0.9.0` is intentionally narrow:

- Rails 8+
- dev/test only
- request-centric logging
- no attempt to compact arbitrary `Rails.logger.info(...)` strings

## Development

```bash
bundle exec rspec
```

## License

MIT
