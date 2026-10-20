require "test_helper"

module Alerts
  class ErrorSubscriberTest < ActiveSupport::TestCase
    include ActiveJob::TestHelper

    setup do
      @subscriber = ErrorSubscriber.new(cache: ActiveSupport::Cache::MemoryStore.new)
      @error = RuntimeError.new("boom")
    end

    test "an unhandled error becomes an alert naming the error" do
      assert_enqueued_with(job: AlertJob) do
        @subscriber.report(@error, handled: false, severity: :error, context: {}, source: "application")
      end
      assert_match(/RuntimeError.*boom/, enqueued_jobs.sole["arguments"].first)
    end

    test "the same error class is reported at most once per window" do
      2.times { @subscriber.report(@error, handled: false, severity: :error, context: {}, source: "application") }
      assert_enqueued_jobs 1
    end

    test "handled errors are left alone" do
      @subscriber.report(@error, handled: true, severity: :warning, context: {}, source: "application")
      assert_no_enqueued_jobs
    end
  end
end
