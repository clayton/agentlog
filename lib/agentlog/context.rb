# frozen_string_literal: true

module Agentlog
  class Context
    attr_reader :jobs, :params, :sql_groups
    attr_accessor :action,
                  :controller,
                  :format,
                  :method,
                  :path,
                  :started_at

    def initialize(path:, method:, controller:, action:, format:, params:)
      @path = path
      @method = method
      @controller = controller
      @action = action
      @format = format
      @params = params
      @jobs = []
      @sql_groups = Hash.new { |hash, key| hash[key] = { count: 0, duration: 0.0 } }
    end

    def add_sql(name:, duration_ms:)
      sql_groups[name][:count] += 1
      sql_groups[name][:duration] += duration_ms
    end

    def add_job(job:)
      jobs << job
    end
  end
end
