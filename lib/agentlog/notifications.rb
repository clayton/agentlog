# frozen_string_literal: true

module Agentlog
  class Notifications
    SQL_NOISE = /\A(?:SCHEMA|TRANSACTION)\z/

    def initialize(configuration:, logger:)
      @configuration = configuration
      @logger = logger
      @compactor = Compactor.new(configuration)
      @subscriptions = []
    end

    def install!
      @subscriptions << ActiveSupport::Notifications.subscribe(
        "start_processing.action_controller"
      ) do |_name, start, _finish, _id, payload|
        start_processing(start, payload)
      end

      @subscriptions << ActiveSupport::Notifications.subscribe(
        "sql.active_record"
      ) do |_name, start, finish, _id, payload|
        sql(start, finish, payload)
      end

      @subscriptions << ActiveSupport::Notifications.subscribe(
        "enqueue.active_job"
      ) do |_name, _start, _finish, _id, payload|
        enqueue(payload)
      end

      @subscriptions << ActiveSupport::Notifications.subscribe(
        "process_action.action_controller"
      ) do |_name, start, finish, _id, payload|
        process_action(start, finish, payload)
      end
    end

    def uninstall!
      @subscriptions.each { |subscription| ActiveSupport::Notifications.unsubscribe(subscription) }
      @subscriptions.clear
    end

    def start_processing(started_at, payload)
      Thread.current[:agentlog_context] = Context.new(
        path: payload[:path] || payload[:original_fullpath],
        method: payload[:method],
        controller: payload[:controller],
        action: payload[:action],
        format: payload[:format],
        params: filtered_params(payload[:params] || {})
      ).tap { |context| context.started_at = started_at }
    end

    def sql(start, finish, payload)
      return unless configuration.log_sql

      context = current_context
      return unless context
      return if payload[:cached]
      return if payload[:name].to_s.match?(SQL_NOISE)

      context.add_sql(name: payload[:name].to_s, duration_ms: milliseconds(start, finish))
    end

    def enqueue(payload)
      return unless configuration.log_jobs

      context = current_context
      return unless context

      job = payload[:job]
      context.add_job(
        job: {
          class_name: job.class.name,
          queue_name: job.queue_name,
          arguments: @compactor.compact(job.arguments || [])
        }
      )
    end

    def process_action(start, finish, payload)
      context = current_context || start_processing(start, payload)
      duration_ms = milliseconds(start, finish)

      emit_request_line(context, payload, duration_ms)
      emit_sql_lines(context)
      emit_job_lines(context)
      emit_exception_line(payload)
    ensure
      Thread.current[:agentlog_context] = nil
    end

    private

    attr_reader :configuration, :logger

    def current_context
      Thread.current[:agentlog_context]
    end

    def emit_request_line(context, payload, duration_ms)
      parts = []
      parts << timestamp(context.started_at || Time.now)
      parts << "REQ"
      parts << context.method.to_s.upcase
      parts << compact_path(context.path)
      parts << "->"
      parts << status_for(payload)
      parts << format_ms(duration_ms)
      parts << "ctrl=#{controller_name(context)}"
      parts << "fmt=#{format_name(context.format)}"
      parts << "params=#{@compactor.compact(context.params)}" if configuration.log_params && context.params.any?
      parts << "db=#{format_ms(payload[:db_runtime])}/#{payload[:db_count] || sql_count(context)}q"
      parts << "view=#{format_ms(payload[:view_runtime])}" if payload.key?(:view_runtime)
      parts << "gc=#{format_ms(payload[:gc_runtime])}" if payload.key?(:gc_runtime)
      logger.info(parts.compact.join(" "))
    end

    def emit_sql_lines(context)
      return unless configuration.log_sql

      context.sql_groups.each do |name, data|
        next unless sql_noteworthy?(data)

        logger.info(
          [
            timestamp(Time.now),
            "SQL",
            name.gsub(/\s+/, "_"),
            "x#{data[:count]}",
            format_ms(data[:duration])
          ].join(" ")
        )
      end
    end

    def emit_job_lines(context)
      return unless configuration.log_jobs

      context.jobs.each do |job|
        logger.info(
          [
            timestamp(Time.now),
            "JOB",
            "enqueue",
            job[:class_name],
            "queue=#{job[:queue_name]}",
            "args=#{job[:arguments]}"
          ].join(" ")
        )
      end
    end

    def emit_exception_line(payload)
      exception = payload[:exception_object]
      return unless exception

      logger.info(
        [
          timestamp(Time.now),
          "ERR",
          exception.class.name,
          %(msg=#{exception.message.inspect})
        ].join(" ")
      )
    end

    def filtered_params(params)
      params.reject { |key, _value| %w[controller action].include?(key.to_s) }
    end

    def sql_noteworthy?(data)
      data[:count] >= configuration.repeat_sql_threshold || data[:duration] >= configuration.slow_sql_ms
    end

    def sql_count(context)
      context.sql_groups.values.sum { |entry| entry[:count] }
    end

    def format_name(format)
      value = format.respond_to?(:ref) ? format.ref : format
      value = value.to_s
      value.empty? ? "any" : value
    end

    def controller_name(context)
      [context.controller.to_s.sub(/Controller\z/, "").underscore, context.action].compact.join("#")
    end

    def compact_path(path)
      value = path.to_s
      value.empty? ? "-" : value
    end

    def format_ms(value)
      format("%.1fms", value.to_f)
    end

    def milliseconds(start, finish)
      ((finish - start) * 1000.0).round(1)
    end

    def status_for(payload)
      payload[:status] || (payload[:exception_object] ? 500 : 200)
    end

    def timestamp(time)
      time.strftime(configuration.time_format)
    end
  end
end
