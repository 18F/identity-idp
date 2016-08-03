class Analytics
  def initialize(user, request)
    @user = user
    @request = request
  end

  def track_event(event, subject = user)
    uuid = subject.uuid

    AnalyticsEventJob.perform_later(
      google_analytics_options.merge(action: event, user_id: uuid)
    )

    Rails.logger.info("#{event} by #{uuid}")

    ahoy.track(event, request_attributes.merge(user_id: uuid))
  end

  def track_anonymous_event(event, attribute = nil)
    AnalyticsEventJob.perform_later(
      google_analytics_options.merge(action: event, value: attribute)
    )

    Rails.logger.info("#{event}: #{attribute}")

    ahoy.track(event, request_attributes.merge(value: attribute))
  end

  def track_pageview
    ahoy.track_visit
  end

  private

  attr_reader :user, :request

  def google_analytics_options
    @google_analytics_options ||= request_attributes.merge(
      anonymize_ip: true
    )
  end

  def request_attributes
    {
      user_ip: request.remote_ip,
      user_agent: request.user_agent
    }
  end

  def ahoy
    @ahoy ||= Rails.env.test? ? FakeAhoyTracker.new : Ahoy::Tracker.new(request: request)
  end
end
