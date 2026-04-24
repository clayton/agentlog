# frozen_string_literal: true

module Agentlog
  class Railtie < Rails::Railtie
    config.agentlog = ActiveSupport::OrderedOptions.new

    initializer "agentlog.configure" do |app|
      options = app.config.agentlog

      Agentlog.configure do |config|
        config.enabled = options.enabled unless options.enabled.nil?
        config.path = options.path if options.path
        config.logger = options.logger if options.logger
        config.log_jobs = options.log_jobs unless options.log_jobs.nil?
        config.log_params = options.log_params unless options.log_params.nil?
        config.log_sql = options.log_sql unless options.log_sql.nil?
        config.max_array_samples = options.max_array_samples if options.max_array_samples
        config.max_hash_pairs = options.max_hash_pairs if options.max_hash_pairs
        config.preserve_keys = options.preserve_keys if options.preserve_keys
        config.repeat_sql_threshold = options.repeat_sql_threshold if options.repeat_sql_threshold
        config.slow_sql_ms = options.slow_sql_ms if options.slow_sql_ms
        config.time_format = options.time_format if options.time_format
      end
    end

    config.after_initialize do
      Agentlog.install!(environment: Rails.env)
    end
  end
end
