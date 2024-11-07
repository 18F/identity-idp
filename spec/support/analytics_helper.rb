module AnalyticsHelper
  def stub_analytics(user: nil)
    analytics = FakeAnalytics.new

    allow(controller).to receive(:analytics).and_wrap_original do |original|
      expect(original.call.user).to eq(user) if user
      analytics
    end

    @analytics = analytics
  end

  def unstub_analytics
    controller.analytics = nil
    @analytics = nil
  end
end
