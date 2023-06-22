module AnalyticsHelper
  def stub_analytics
    controller.analytics = FakeAnalytics.new
    @analytics = controller.analytics
  end

  def unstub_analytics
    controller.analytics = nil
    @analytics = nil
  end
end
