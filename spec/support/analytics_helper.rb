module AnalyticsHelper
  def stub_analytics(user: nil)
    analytics = FakeAnalytics.new

    if user
      allow(controller).to receive(:analytics) do
        expect(controller.analytics_user).to eq(user)
        analytics
      end
    else
      controller.analytics = analytics
    end

    @analytics = analytics
  end

  def unstub_analytics
    controller.analytics = nil
    @analytics = nil
  end
end
