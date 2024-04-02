# frozen_string_literal: true

class UserSessionContext
  AUTHENTICATION_CONTEXT = 'authentication'
  REAUTHENTICATION_CONTEXT = 'reauthentication'
  CONFIRMATION_CONTEXT = 'confirmation'

  def self.authentication_context?(context)
    context == AUTHENTICATION_CONTEXT
  end

  def self.reauthentication_context?(context)
    context == REAUTHENTICATION_CONTEXT
  end

  def self.authentication_or_reauthentication_context?(context)
    authentication_context?(context) || reauthentication_context?(context)
  end

  def self.confirmation_context?(context)
    context == CONFIRMATION_CONTEXT
  end
end
