class UserPivCacVerificationForm
  include ActiveModel::Model
  include PivCacFormHelpers

  attr_accessor :x509_dn_uuid, :x509_dn, :token, :error_type, :nonce, :user

  validates :token, presence: true
  validates :nonce, presence: true
  validates :user, presence: true

  def submit
    success = valid? && valid_submission?

    FormResponse.new(
      success: success,
      errors: {},
      extra: extra_analytics_attributes,
    )
  end

  private

  def valid_submission?
    user_has_piv_cac &&
      valid_token? &&
      x509_cert_matches
  end

  def x509_cert_matches
    if MfaContext.new(user).piv_cac_configuration.mfa_confirmed?(x509_dn_uuid)
      true
    else
      self.error_type = 'user.piv_cac_mismatch'
      false
    end
  end

  def user_has_piv_cac
    if TwoFactorAuthentication::PivCacPolicy.new(user).enabled?
      true
    else
      self.error_type = 'user.no_piv_cac_associated'
      false
    end
  end

  def extra_analytics_attributes
    {
      multi_factor_auth_method: 'piv_cac',
    }
  end
end
