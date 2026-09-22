module AnalyticsHelper
  def stub_analytics(user: nil)
    analytics = FakeAnalytics.new

    stub = if defined?(controller)
             allow(controller)
           else
             allow_any_instance_of(ApplicationController)
           end

    stub.to receive(:analytics).and_wrap_original do |original|
      expect(original.call.user).to match(user) if user
      analytics
    end

    @analytics = analytics
  end

  def stub_job_analytics(user: nil)
    analytics = FakeAnalytics.new

    stub = if defined?(job)
             allow(job)
           else
             allow_any_instance_of(ApplicationJob)
           end

    stub.to receive(:analytics).and_wrap_original do |original|
      expect(original.call.user).to match(user) if user
      analytics
    end

    @analytics = analytics
  end

  def unstub_analytics
    controller.analytics = nil if defined?(controller)
    job.analytics = nil if defined?(job)
    @analytics = nil
  end

  class EventNotYetLogged < StandardError; end

  # Waits, using Capybara's synchronization, for an analytics event to be logged. Events sent from
  # the browser (navigator.sendBeacon) can arrive after the test thread has moved on, so a plain
  # expectation can race the request. Falls through to the expectation on timeout so a miss
  # reports the full event diff.
  def wait_for_logged_event(
    analytics,
    event,
    attributes = nil,
    wait: Capybara.default_max_wait_time
  )
    matcher = have_logged_event(event, attributes)
    page.document.synchronize(wait, errors: [EventNotYetLogged]) do
      raise EventNotYetLogged unless matcher.matches?(analytics)
    end
  rescue EventNotYetLogged
    expect(analytics).to matcher
  end
end
