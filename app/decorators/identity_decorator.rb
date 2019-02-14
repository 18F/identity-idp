IdentityDecorator = Struct.new(:identity) do
  delegate :display_name, to: :identity
  delegate :agency_name, to: :identity

  def connected_app_partial
    'accounts/connected_app'
  end

  def event_partial
    'accounts/identity_item'
  end

  def failure_to_proof_url
    identity.sp_metadata[:failure_to_proof_url]
  end

  def return_to_sp_url
    identity.sp_metadata[:return_to_sp_url]
  end

  def friendly_name
    identity.sp_metadata[:friendly_name]
  end

  def created_at_in_words
    UtcTimePresenter.new(created_at).to_s
  end

  def created_at
    identity.created_at.utc
  end

  def happened_at
    identity.last_authenticated_at.utc
  end

  def happened_at_in_words
    UtcTimePresenter.new(happened_at).to_s
  end
end
