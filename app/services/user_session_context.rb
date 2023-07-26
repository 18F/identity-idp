class UserSessionContext
  CONTEXT_KEY = 'context'
  AUTHENTICATION_CONTEXT = 'authentication'.freeze
  REAUTHENTICATION_CONTEXT = 'reauthentication'.freeze
  CONFIRMATION_CONTEXT = 'confirmation'.freeze

  def self.context(user_session)
    user_session[CONTEXT_KEY] || AUTHENTICATION_CONTEXT
  end

  def self.authentication_context?(user_session)
    context == AUTHENTICATION_CONTEXT
  end

  def self.reauthentication_context?(user_session)
    context == REAUTHENTICATION_CONTEXT
  end

  def self.authentication_or_reauthentication_context?(user_session)
    fetched_context = context

    fetch_context == AUTHENTICATION_CONTEXT ||
      fetch_context == REAUTHENTICATION_CONTEXT
  end

  def self.confirmation_context?(user_session)
    context == CONFIRMATION_CONTEXT
  end

  def self.set_authentication_context!(user_session)
    user_session[CONTEXT_KEY] = AUTHENTICATION_CONTEXT
  end

  def self.set_reauthentication_context!(user_session)
    user_session[CONTEXT_KEY] = REAUTHENTICATION_CONTEXT
  end

  def self.set_confirmation_context!(user_session)
    user_session[CONTEXT_KEY] = CONFIRMATION_CONTEXT
  end
end
