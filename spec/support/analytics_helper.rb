module AnalyticsHelper
  def stub_analytics(user: AnonymousUser.new)
    controller.analytics = FakeAnalytics.new(user: user)
    @analytics = controller.analytics
  end
end
