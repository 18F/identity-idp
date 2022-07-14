class TwoFactorOptionsForm
  include ActiveModel::Model

  attr_reader :selection
  attr_reader :configuration_id

  validates :selection, inclusion: { in: %w[phone sms voice auth_app piv_cac
                                            webauthn webauthn_platform
                                            backup_code] }

  validates :selection, length: { minimum: 1 }
  validates :selection, length: { minimum: 2, message: 'phone' }, if: :phone_validations?

  def initialize(user)
    self.user = user
  end

  def submit(params)
    self.selection = Array(params[:selection]).filter(&:present?)

    success = valid?
    update_otp_delivery_preference_for_user if success && user_needs_updating?
    FormResponse.new(success: success, errors: errors, extra: extra_analytics_attributes)
  end

  private

  attr_accessor :user
  attr_writer :selection

  def mfa_user
    @mfa_user ||= MfaContext.new(user)
  end

  def extra_analytics_attributes
    {
      selection: selection,
      enabled_mfa_methods_count: mfa_user.enabled_mfa_methods_count,
    }
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

  def phone_only_mfa_method?
    MfaContext.new(user).enabled_mfa_methods_count == 0
  end

  def kantara_2fa_phone_restricted?
    IdentityConfig.store.kantara_2fa_phone_restricted
  end

  def phone_alternative_enabled?
    count = MfaContext.new(user).enabled_mfa_methods_count
    count >= 2 || (count == 1 && MfaContext.new(user).phone_configurations.none?)
  end

  def phone_validations?
    IdentityConfig.store.select_multiple_mfa_options &&
      phone_selected? && phone_only_mfa_method? &&
      !phone_alternative_enabled? && kantara_2fa_phone_restricted?
  end
end
