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
end
