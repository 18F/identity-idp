module EffectiveUser
  def effective_user_id
    [
      session[:ial2_recovery_user_id],
      session[:doc_capture_user_id],
      current_user&.id,
    ].find(&:present?)
  end

  def effective_user
    User.find_by(id: effective_user_id) if effective_user_id
  end
end
