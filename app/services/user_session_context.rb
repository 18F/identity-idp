class UserSessionContext
  DEFAULT_CONTEXT = 'authentication'.freeze
  REAUTHENTICATION_CONTEXT = 'reauthentication'.freeze
  CONFIRMATION_CONTEXT = 'confirmation'.freeze

  def self.initial_authentication_context?(context)
    context == DEFAULT_CONTEXT
  end

  def self.authentication_context?(context)
    context == DEFAULT_CONTEXT || context == REAUTHENTICATION_CONTEXT
  end

  def self.confirmation_context?(context)
    context == CONFIRMATION_CONTEXT
  end
end
