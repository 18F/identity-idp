class TwoFactorOptionsForm
  include ActiveModel::Model

  attr_accessor :selection, :user, :phishing_resistant_required, :piv_cac_required

  validates :selection, inclusion: { in: %w[phone sms voice auth_app piv_cac
                                            webauthn webauthn_platform
                                            backup_code] }

  validates :selection, length: { minimum: 1 }, if: :has_no_mfa_or_in_required_flow?

  def initialize(user:, phishing_resistant_required:, piv_cac_required:)
    self.user = user
    self.phishing_resistant_required = phishing_resistant_required
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

  def in_phishing_resistant_or_piv_cac_required_flow?
    phishing_resistant_required || piv_cac_required
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
    has_no_configured_mfa? || in_phishing_resistant_or_piv_cac_required_flow?
  end
end
