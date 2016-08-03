module AnalyticsHelper
  def stub_analytics
    @analytics = controller.analytics(FakeAnalytics.new)
  end
end
