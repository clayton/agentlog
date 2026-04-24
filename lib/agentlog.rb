# frozen_string_literal: true

require "active_support"
require "active_support/core_ext/module/attribute_accessors"
require "active_support/core_ext/string/inflections"
require "active_support/notifications"
require "logger"

require_relative "agentlog/compactor"
require_relative "agentlog/configuration"
require_relative "agentlog/context"
require_relative "agentlog/notifications"
require_relative "agentlog/version"

module Agentlog
  class Error < StandardError; end

  class << self
    attr_accessor :notifications
    attr_writer :configuration

    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def install!(logger: nil, environment: nil)
      return unless configuration.enabled?(environment)

      @notifications&.uninstall!
      @notifications = Notifications.new(configuration:, logger: logger || build_logger(configuration))
      @notifications.install!
    end

    def reset!
      @notifications&.uninstall!
      @notifications = nil
      @configuration = Configuration.new
      Thread.current[:agentlog_context] = nil
    end

    def build_logger(configuration)
      return configuration.logger if configuration.logger

      logger = ::Logger.new(configuration.path)
      logger.formatter = proc { |_severity, _time, _progname, message| "#{message}\n" }
      logger
    end
  end
end

require_relative "agentlog/railtie" if defined?(Rails::Railtie)
