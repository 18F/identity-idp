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

  def idv_context?
    context == 'idv'
  end

  def idv_or_confirmation_context?
    confirmation_context? || idv_context?
  end

  def idv_or_profile_context?
    idv_context? || profile_context?
  end

  def profile_context?
    context == 'profile'
  end
end
