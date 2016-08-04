module AnalyticsHelper
  def stub_analytics
    controller.analytics = FakeAnalytics.new
    @analytics = controller.analytics
  end
end
