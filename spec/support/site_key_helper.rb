module SiteKeyHelper
  CreatedSiteKey = Struct.new(:record, :private_key, :recovery_code, keyword_init: true)

  # Creates the user's site key wrapped under the password, as a sign-in to a listed client would,
  # along with its recovery-code wrap. By default the recovery code is left unacknowledged, so the
  # key is not yet recoverable; pass acknowledge: true for a key that survives a password reset.
  def create_site_key(user, password: user.password, acknowledge: false)
    session = {}
    vault = SiteKeys::Vault.new(user:, user_session: session)
    private_key = vault.unlock(password, create: true)
    code = vault.pending_recovery_code
    vault.acknowledge_recovery_code if acknowledge
    CreatedSiteKey.new(record: user.reload.site_key, private_key:, recovery_code: code)
  end

  # Lists the service provider for site keys and for key binding, which the listing requires.
  def allow_site_keys_for(service_provider)
    allow(IdentityConfig.store).to receive(:site_key_allowed_issuers)
      .and_return([service_provider.issuer])
    allow(IdentityConfig.store).to receive(:dpop_required_issuers)
      .and_return([service_provider.issuer])
  end
end
