class UserSessionContext
  AUTHENTICATION_CONTEXT = 'authentication'.freeze
  REAUTHENTICATION_CONTEXT = 'reauthentication'.freeze
  CONFIRMATION_CONTEXT = 'confirmation'.freeze

  def self.authentication_context?(context)
    context == AUTHENTICATION_CONTEXT
  end

  def self.reauthentication_context?(context, user_fully_authenticated)
    context == REAUTHENTICATION_CONTEXT && user_fully_authenticated
  end

  def self.authentication_or_reauthentication_context?(context, user_fully_authenticated)
    authentication_context?(context) || reauthentication_context?(context, user_fully_authenticated)
  end

  def self.confirmation_context?(context)
    context == CONFIRMATION_CONTEXT
  end
end
