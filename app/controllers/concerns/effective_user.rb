# frozen_string_literal: true

module EffectiveUser
  def effective_user
    return current_user if effective_user_id == current_user&.id
    return User.find_by(id: effective_user_id) if effective_user_id
  end

  private

  def effective_user_id
    [
      session[:doc_capture_user_id],
      current_user&.id,
    ].find(&:present?)
  end
end
