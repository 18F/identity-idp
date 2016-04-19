OmniauthCallbackPolicy = Struct.new(:user, :omniauth_callback) do
  AUTHORIZED_TECH_SUPPORT_SAML_GROUP =  'cn=ENT-SG-UPAYA-PWRESET,ou=groups,ou=upayainternal,ou=upayaenterprise,dc=upaya,dc=18f,dc=gov'.freeze
  AUTHORIZED_ADMIN_SAML_GROUP =         'cn=ENT-SG-UPAYA-WEBADMIN,ou=groups,ou=upayainternal,ou=upayaenterprise,dc=upaya,dc=18f,dc=gov'.freeze

  def saml?
    return false unless FeatureManagement.allow_enterprise_auth?

    groups = user.context

    return false unless groups.present?
    return true if groups.to_s.downcase.include? AUTHORIZED_TECH_SUPPORT_SAML_GROUP.downcase
    return true if groups.to_s.downcase.include? AUTHORIZED_ADMIN_SAML_GROUP.downcase
  end
end
