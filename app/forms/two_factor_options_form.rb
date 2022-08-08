class TwoFactorOptionsForm
  include ActiveModel::Model

  attr_accessor :selection, :user, :aal3_required, :piv_cac_required

  validates :selection, inclusion: { in: %w[phone sms voice auth_app piv_cac
                                            webauthn webauthn_platform
                                            backup_code] }

  validates :selection, length: { minimum: 1 }, if: :has_no_mfa_or_in_required_flow?
  validates :selection, length: { minimum: 2, message: 'phone' }, if: :phone_validations?

  def initialize(user:, aal3_required:, piv_cac_required:)
    self.user = user
    self.aal3_required = aal3_required
    self.piv_cac_required = piv_cac_required
  end

  def submit(params)
    self.selection = Array(params[:selection]).filter(&:present?)

    success = valid?
    update_otp_delivery_preference_for_user if success && user_needs_updating?
    FormResponse.new(success: success, errors: errors, extra: extra_analytics_attributes)
  end

  private

  def mfa_user
    @mfa_user ||= MfaContext.new(user)
  end

  def extra_analytics_attributes
    {
      selection: selection,
      selected_mfa_count: selection.count,
      enabled_mfa_methods_count: mfa_user.enabled_mfa_methods_count,
    }
  end

  def in_aal3_or_piv_cac_required_flow?
    aal3_required || piv_cac_required
  end

  def user_needs_updating?
    (%w[voice sms] & selection).present? &&
      !selection.include?(user.otp_delivery_preference)
  end

  def update_otp_delivery_preference_for_user
    user_attributes = { otp_delivery_preference:
      selection.find { |element| %w[voice sms].include?(element) } }
    UpdateUser.new(user: user, attributes: user_attributes).call
  end

  def phone_selected?
    selection.include?('phone') || selection.include?('voice') || selection.include?('sms')
  end

  def has_no_configured_mfa?
    mfa_user.enabled_mfa_methods_count == 0
  end

  def has_no_mfa_or_in_required_flow?
    has_no_configured_mfa? || in_aal3_or_piv_cac_required_flow?
  end

  def kantara_2fa_phone_restricted?
    IdentityConfig.store.kantara_2fa_phone_restricted
  end

  def phone_alternative_enabled?
    count = mfa_user.enabled_mfa_methods_count
    count >= 2 || (count == 1 && MfaContext.new(user).phone_configurations.none?)
  end

  def phone_validations?
    IdentityConfig.store.select_multiple_mfa_options &&
      phone_selected? && has_no_configured_mfa? &&
      !phone_alternative_enabled? && kantara_2fa_phone_restricted?
  end
end
