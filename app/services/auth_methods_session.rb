class AuthMethodsSession
  attr_reader :user_session

  MAX_AUTH_EVENTS = 10

  def initialize(user_session:)
    @user_session = user_session
  end

  def authenticate!(auth_method)
    user_session[TwoFactorAuthenticatable::NEED_AUTHENTICATION] = false
    user_session[:auth_events] = auth_events.
      push({ auth_method:, at: Time.zone.now }).
      last(MAX_AUTH_EVENTS)
  end

  def auth_events
    user_session[:auth_events] || []
  end
end
