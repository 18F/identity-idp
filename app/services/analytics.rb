class Analytics
  def initialize(user, request)
    @user = user
    @request = request
  end

  def track_event(event, attributes = { user_id: uuid })
    attributes[:user_id] = uuid unless attributes.key?(:user_id)

    Rails.logger.info("#{event}: #{attributes}")

    ahoy.track(event, attributes.merge!(request_attributes))
  end

  private

  attr_reader :user, :request

  def request_attributes
    {
      user_ip: request.remote_ip,
      user_agent: request.user_agent
    }
  end

  def ahoy
    @ahoy ||= Rails.env.test? ? FakeAhoyTracker.new : Ahoy::Tracker.new(request: request)
  end

  def uuid
    user.uuid
  end
end
