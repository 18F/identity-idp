OmniauthCallbackPolicy = Struct.new(:user, :omniauth_callback) do
  def saml?
    FeatureManagement.allow_third_party_auth?
  end
end
