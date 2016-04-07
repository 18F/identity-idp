class OmniauthCallbackPolicy < Struct.new(:user, :omniauth_callback)
  AUTHORIZED_TECH_SUPPORT_SAML_GROUP =  'cn=ENT-SG-UPAYA-PWRESET,ou=groups,ou=upayainternal,ou=upayaenterprise,dc=upaya,dc=18f,dc=gov'
  AUTHORIZED_ADMIN_SAML_GROUP =         'cn=ENT-SG-UPAYA-WEBADMIN,ou=groups,ou=upayainternal,ou=upayaenterprise,dc=upaya,dc=18f,dc=gov'

  def saml?
    return false unless FeatureManagement.allow_ent_icam_auth?

    groups = user.context

    return false unless groups.present?
    return true if groups.to_s.downcase.include? AUTHORIZED_TECH_SUPPORT_SAML_GROUP.downcase
    return true if groups.to_s.downcase.include? AUTHORIZED_ADMIN_SAML_GROUP.downcase
  end
end
