class UserSessionContext
  DEFAULT_CONTEXT = 'authentication'.freeze
  REAUTHENTICATION_CONTEXT = 'reauthentication'.freeze
  CONFIRMATION_CONTEXT = 'confirmation'.freeze

  def self.initial_authentication_context?(context)
    context == DEFAULT_CONTEXT
  end

  def self.reauthentication_context?(context)
    context == REAUTHENTICATION_CONTEXT
  end

  def self.authentication_context?(context)
    initial_authentication_context?(context) || reauthentication_context?(context)
  end

  def self.confirmation_context?(context)
    context == CONFIRMATION_CONTEXT
  end
end
