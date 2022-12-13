class UserPivCacVerificationForm
  include ActiveModel::Model
  include PivCacFormHelpers

  attr_accessor :x509_dn_uuid,
                :x509_dn,
                :x509_issuer,
                :token,
                :error_type,
                :nonce,
                :user,
                :key_id,
                :piv_cac_required,
                :piv_cac_configuration

  validates :token, presence: true
  validates :nonce, presence: true
  validates :user, presence: true

  def submit
    success = valid? && valid_submission?
    errors = error_type ? { type: error_type } : {}

    FormResponse.new(
      success: success,
      errors: errors,
      extra: extra_analytics_attributes.merge(error_type ? { key_id: key_id } : {}),
    )
  end

  private

  def valid_submission?
    user_has_piv_cac &&
      valid_token? &&
      x509_cert_matches
  end

  def x509_cert_matches
    piv_cac_configuration = ::PivCacConfiguration.find_by(x509_dn_uuid: x509_dn_uuid)
    if user == piv_cac_configuration&.user
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
      piv_cac_configuration_id: piv_cac_configuration&.id,
    }
  end
end
