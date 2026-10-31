module SiteKeyHelper
  CreatedSiteKey = Struct.new(:record, :private_key, keyword_init: true)

  # Creates the user's site key wrapped under the password, as a sign-in to a listed client would.
  def create_site_key(user, password: user.password)
    private_key = SiteKeys::Vault.new(user:, user_session: {}).unlock(password, create: true)
    CreatedSiteKey.new(record: user.reload.site_key, private_key:)
  end

  # Lists the service provider for site keys and for key binding, which the listing requires.
  def allow_site_keys_for(service_provider)
    allow(IdentityConfig.store).to receive(:site_key_allowed_issuers)
      .and_return([service_provider.issuer])
    allow(IdentityConfig.store).to receive(:dpop_required_issuers)
      .and_return([service_provider.issuer])
  end
end
