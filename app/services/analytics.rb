class Analytics
  def initialize(user, request_attributes, ahoy)
    @user = user
    @request_attributes = request_attributes
    @ahoy = ahoy
  end

  def track_event(event, subject = user)
    uuid = subject.uuid

    AnalyticsEventJob.perform_later(
      common_options.merge(action: event, user_id: uuid)
    )

    Rails.logger.info("#{event} by #{uuid}")

    ahoy.track(event)
  end

  def track_anonymous_event(event, attribute = nil)
    AnalyticsEventJob.perform_later(
      common_options.merge(action: event, value: attribute)
    )

    Rails.logger.info("#{event}: #{attribute}")

    ahoy.track(event, value: attribute)
  end

  def track_pageview
    ahoy.track_visit
  end

  private

  attr_reader :user, :ahoy

  def common_options
    @common_options ||= @request_attributes.merge(
      anonymize_ip: true
    )
  end
end
