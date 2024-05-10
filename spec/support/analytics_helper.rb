module AnalyticsHelper
  def stub_analytics(user: nil)
    @analytics = FakeAnalytics.new

    allow(controller).to receive(:analytics).and_wrap_original do |_original|
      expect(controller.analytics_user).to eq(user) if user
      allow(controller).to receive(:analytics).and_call_original
      controller.analytics = @analytics
    end

    @analytics
  end

  def unstub_analytics
    controller.analytics = nil
    @analytics = nil
  end
end
