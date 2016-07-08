class Analytics
  def initialize(user, request_attributes)
    @user = user
    @request_attributes = request_attributes
  end

  def track_event(event, subject = user)
    AnalyticsEventJob.perform_later(
      common_options.merge(action: event, user_id: subject.uuid)
    )
  end

  def track_anonymous_event(event, attribute = nil)
    AnalyticsEventJob.perform_later(
      common_options.merge(action: event, value: attribute)
    )
  end

  private

  attr_reader :user

  def common_options
    @common_options ||= @request_attributes.merge(
      anonymize_ip: true
    )
  end
end
