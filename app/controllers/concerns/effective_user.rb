module EffectiveUser
  def effective_user_id
    [
      user_session_or_session[:ial2_recovery_user_id],
      user_session_or_session[:doc_capture_user_id],
      current_user&.id,
    ].find(&:present?)
  end

  def effective_user
    User.find_by(id: effective_user_id) if effective_user_id
  end

  def user_session_or_session
    user_session || session
  end
end
