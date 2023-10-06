class AuthMethodsSession
  attr_reader :user_session

  def initialize(user_session:)
    @user_session = user_session
  end

  def authenticate!(auth_method)
    user_session[TwoFactorAuthenticatable::NEED_AUTHENTICATION] = false
    auth_events << { auth_method:, at: Time.zone.now }
  end

  def auth_events
    user_session[:auth_events] ||= []
  end
end
