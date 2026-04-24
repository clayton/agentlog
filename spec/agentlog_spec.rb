# frozen_string_literal: true

RSpec.describe Agentlog do
  class MemoryLogger
    attr_reader :messages

    def initialize
      @messages = []
    end

    def info(message)
      messages << message
    end
  end

  class TestJob
    attr_reader :arguments, :queue_name

    def initialize(arguments:, queue_name:)
      @arguments = arguments
      @queue_name = queue_name
    end
  end

  after do
    Agentlog.reset!
  end

  it "has a version number" do
    expect(Agentlog::VERSION).to eq("0.9.0")
  end

  it "compacts nested values while preserving configured keys" do
    configuration = Agentlog::Configuration.new
    configuration.preserve_keys = %w[user_id]
    compactor = Agentlog::Compactor.new(configuration)

    result = compactor.compact(
      {
        user_id: 4239,
        session_id: "0ECD7289-EB1B-449C-8C43-B6734473542A",
        events: [
          {
            event_name: "Home Viewed",
            properties: { active_task_count: 10, variant: "steady" }
          }
        ]
      }
    )

    expect(result).to include("user_id:4239")
    expect(result).to include("session_id:str(36)")
    expect(result).to include("events:[{event_name:str(11),properties:{active_task_count:int,variant:str(6)}}]")
  end

  it "emits compact request, sql, job, and error lines" do
    logger = MemoryLogger.new
    configuration = Agentlog::Configuration.new
    configuration.preserve_keys = %w[user_id]
    configuration.repeat_sql_threshold = 2
    notifications = Agentlog::Notifications.new(configuration:, logger:)

    started_at = Time.utc(2026, 4, 24, 17, 48, 1)

    notifications.start_processing(
      started_at,
      {
        path: "/api/v1/app_events",
        method: "POST",
        controller: "Api::V1::AppEventsController",
        action: "create",
        format: :json,
        params: {
          "controller" => "Api::V1::AppEventsController",
          "action" => "create",
          "user_id" => 4239,
          "device_id" => "E12AB6BE-8CB7-48A8-9972-1F52DD56C527",
          "events" => [{ "event_name" => "Home Viewed", "platform" => "ios" }]
        }
      }
    )

    notifications.sql(started_at, started_at + 0.001, { name: "NotificationToken Load" })
    notifications.sql(started_at + 0.001, started_at + 0.003, { name: "NotificationToken Load" })
    notifications.enqueue(job: TestJob.new(arguments: [4239, "/api/v1/app_events"], queue_name: "default"))
    notifications.process_action(
      started_at,
      started_at + 0.008,
      {
        path: "/api/v1/app_events",
        method: "POST",
        controller: "Api::V1::AppEventsController",
        action: "create",
        format: :json,
        status: 202,
        db_runtime: 3.4,
        view_runtime: 0.1,
        gc_runtime: 0.0,
        exception_object: RuntimeError.new("boom")
      }
    )

    expect(logger.messages[0]).to include("REQ POST /api/v1/app_events -> 202 8.0ms")
    expect(logger.messages[0]).to include("ctrl=api/v1/app_events#create")
    expect(logger.messages[0]).to include(
      "params={user_id:4239,device_id:str(36),events:[{event_name:str(11),platform:str(3)}]}"
    )
    expect(logger.messages[0]).to include("db=3.4ms/2q")

    expect(logger.messages[1]).to include("SQL NotificationToken_Load x2 3.0ms")
    expect(logger.messages[2]).to include("JOB enqueue TestJob queue=default args=[int|str(18)]")
    expect(logger.messages[3]).to include('ERR RuntimeError msg="boom"')
  end

  it "defaults to development and test only" do
    configuration = Agentlog::Configuration.new

    expect(configuration.enabled?(:development)).to be(true)
    expect(configuration.enabled?(:test)).to be(true)
    expect(configuration.enabled?(:production)).to be(false)
  end
end
