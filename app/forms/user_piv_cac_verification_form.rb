# frozen_string_literal: true

class UserPivCacVerificationForm
  include ActiveModel::Model
  include PivCacFormHelpers

  attr_accessor :x509_dn_uuid, :x509_dn, :x509_issuer, :token, :error_type, :nonce, :user, :key_id,
                :piv_cac_required

  validates :token, presence: true
  validates :nonce, presence: true
  validates :user, presence: true

  def submit
    success = valid? && valid_submission?

    FormResponse.new(
      success:,
      errors:,
      extra: extra_analytics_attributes,
    )
  end

  def piv_cac_configuration
    return nil if x509_dn_uuid.blank?
    @piv_cac_configuration ||= ::PivCacConfiguration.find_by(x509_dn_uuid: x509_dn_uuid)
  end

  private

  def valid_submission?
    user_has_piv_cac &&
      valid_token? &&
      x509_cert_matches
  end

  def x509_cert_matches
    if user == piv_cac_configuration&.user
      true
    else
      self.error_type = 'user.piv_cac_mismatch'
      errors.add(
        :user, I18n.t('headings.piv_cac_setup.already_associated'),
        type: :piv_cac_mismatch
      )
      false
    end
  end

  def user_has_piv_cac
    if TwoFactorAuthentication::PivCacPolicy.new(user).enabled?
      true
    else
      self.error_type = 'user.no_piv_cac_associated'
      errors.add(
        :user, I18n.t('headings.piv_cac_login.account_not_found'),
        type: :no_piv_cac_associated
      )
      false
    end
  end

  def extra_analytics_attributes
    {
      piv_cac_configuration_id: piv_cac_configuration&.id,
      piv_cac_configuration_dn_uuid: x509_dn_uuid,
      key_id: key_id,
      multi_factor_auth_method_created_at: piv_cac_configuration&.created_at&.strftime('%s%L'),
    }
  end
end
