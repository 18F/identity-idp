module AnalyticsHelper
  def stub_analytics
    controller.analytics = Analytics.create_null
    @analytics = controller.analytics
  end

  def unstub_analytics
    controller.analytics = nil
    @analytics = nil
  end
end
