# frozen_string_literal: true

module Agentlog
  class Configuration
    attr_accessor :enabled,
                  :logger,
                  :log_jobs,
                  :log_params,
                  :log_sql,
                  :max_array_samples,
                  :max_hash_pairs,
                  :path,
                  :preserve_keys,
                  :repeat_sql_threshold,
                  :slow_sql_ms,
                  :time_format

    def initialize
      @enabled = nil
      @logger = nil
      @log_jobs = true
      @log_params = true
      @log_sql = true
      @max_array_samples = 1
      @max_hash_pairs = 6
      @path = "log/agent.log"
      @preserve_keys = []
      @repeat_sql_threshold = 3
      @slow_sql_ms = 25.0
      @time_format = "%H:%M:%S"
    end

    def enabled?(environment = nil)
      return enabled unless enabled.nil?

      env_name =
        if environment.respond_to?(:to_s)
          environment.to_s
        elsif defined?(Rails) && Rails.respond_to?(:env)
          Rails.env.to_s
        end

      %w[development test].include?(env_name)
    end
  end
end
