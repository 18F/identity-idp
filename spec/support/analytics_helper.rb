module AnalyticsHelper
  def stub_analytics(user: nil)
    controller.analytics = FakeAnalytics.new(user:)
    @analytics = controller.analytics
  end

  def unstub_analytics
    controller.analytics = nil
    @analytics = nil
  end
end
