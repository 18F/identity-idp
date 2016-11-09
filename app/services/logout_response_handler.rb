LogoutResponseHandler = Struct.new(:identity, :response, :session_id) do
  def continue_logout_with_next_identity?
    in_slo?
  end

  def no_more_logout_responses?
    response.blank?
  end

  def deactivate_identity
    identity.deactivate(session_id)
  end

  def deactivate_last_identity
    identity.user.last_identity.deactivate(session_id)
  end

  private

  def in_slo?
    user = identity.user

    user.multiple_sessions?(session_id) || (user.active_identities.present? && response.nil?)
  end
end
