LogoutResponseHandler = Struct.new(:identity, :response) do
  def perform
    deactivate_identity

    yield :continue_logout_with_next_identity if in_slo?

    deactivate_last_identity

    yield :no_more_logout_responses if response.blank?
  end

  private

  def deactivate_identity
    identity.deactivate
  end

  def deactivate_last_identity
    identity.user.last_identity.deactivate
  end

  def in_slo?
    user = identity.user

    user.multiple_identities? || (user.active_identities.present? && response.nil?)
  end
end
