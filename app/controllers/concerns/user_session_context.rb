module UserSessionContext
  DEFAULT_CONTEXT = 'authentication'.freeze

  def context
    user_session[:context] || DEFAULT_CONTEXT
  end

  def initial_authentication_context?
    context == DEFAULT_CONTEXT
  end

  def authentication_context?
    context == DEFAULT_CONTEXT || context == 'reauthentication'
  end

  def confirmation_context?
    context == 'confirmation'
  end
end
