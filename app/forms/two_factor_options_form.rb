class TwoFactorOptionsForm
  include ActiveModel::Model
  include ActionView::Helpers::TranslationHelper

  attr_accessor :selection, :user, :phishing_resistant_required, :piv_cac_required

  validates :selection, inclusion: { in: %w[phone sms voice auth_app piv_cac
                                            webauthn webauthn_platform
                                            backup_code] }

  validate :validate_selection_present

  def initialize(user:, phishing_resistant_required:, piv_cac_required:)
    self.user = user
    self.phishing_resistant_required = phishing_resistant_required
    self.piv_cac_required = piv_cac_required
  end

  def submit(params)
    self.selection = params[:selection]

    success = valid?
    update_otp_delivery_preference_for_user if success && user_needs_updating?
    FormResponse.new(success: success, errors: errors, extra: extra_analytics_attributes)
  end

  private

  def validate_selection_present
    return if !has_no_mfa_or_in_required_flow? || selection.present? || phishing_resistant_and_mfa?
    errors.add(:selection, missing_selection_error_message, type: :missing_selection)
  end

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

  def platform_auth_only_option?
    mfa_user.enabled_mfa_methods_count == 1 &&
      mfa_user.webauthn_platform_configurations.count == 1
  end

  def has_no_mfa_or_in_required_flow?
    has_no_configured_mfa? ||
      in_phishing_resistant_or_piv_cac_required_flow? ||
      platform_auth_only_option?
  end

  def phishing_resistant_and_mfa?
    MfaPolicy.new(user).unphishable? && in_phishing_resistant_or_piv_cac_required_flow?
  end

  def missing_selection_error_message
    if has_no_configured_mfa? || in_phishing_resistant_or_piv_cac_required_flow? ||
       phishing_resistant_and_mfa?
      t('errors.two_factor_auth_setup.must_select_option')
    elsif platform_auth_only_option?
      t('errors.two_factor_auth_setup.must_select_additional_option')
    end
  end
end
