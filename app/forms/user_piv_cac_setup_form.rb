class UserPivCacSetupForm
  include ActiveModel::Model
  include PivCacFormHelpers

  attr_accessor :x509_dn_uuid, :x509_dn, :token, :user, :nonce, :error_type

  validates :token, presence: true
  validates :nonce, presence: true
  validates :user, presence: true

  def submit
    success = valid? && valid_submission?

    errors = error_type ? { type: error_type } : {}
    FormResponse.new(
      success: success && process_valid_submission,
      errors: errors,
      extra: extra_analytics_attributes,
    )
  end

  private

  def process_valid_submission
    UpdateUser.new(user: user, attributes: { x509_dn_uuid: x509_dn_uuid }).call
    Db::PivCacConfiguration::Create.call(user.id, x509_dn_uuid)
    true
  rescue PG::UniqueViolation
    self.error_type = 'piv_cac.already_associated'
    false
  end

  def valid_submission?
    valid_token? && piv_cac_not_already_associated
  end

  def piv_cac_not_already_associated
    self.x509_dn_uuid = @data['uuid']
    self.x509_dn = @data['subject']
    if Db::PivCacConfiguration::FindUserByX509.call(x509_dn_uuid)
      self.error_type = 'piv_cac.already_associated'
      false
    else
      true
    end
  end

  def user_has_no_piv_cac
    if TwoFactorAuthentication::PivCacPolicy.new(user).enabled?
      self.error_type = 'user.piv_cac_associated'
      false
    else
      true
    end
  end

  def extra_analytics_attributes
    {
      multi_factor_auth_method: 'piv_cac',
    }
  end
end
