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
    return if selection.present? || has_minimum_required_mfa_methods?
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

  def has_minimum_required_mfa_methods?
    if piv_cac_required
      mfa_user.piv_cac_configurations.count > 0
    elsif mfa_user.webauthn_platform_configurations.any?
      !platform_auth_only_option?
    elsif phishing_resistant_required
      mfa_user.phishing_resistant_configurations.count > 0
    else
      mfa_user.enabled_mfa_methods_count > 0
    end
  end

  def platform_auth_only_option?
    mfa_user.enabled_mfa_methods_count == 1 &&
      mfa_user.webauthn_platform_configurations.count == 1
  end

  def missing_selection_error_message
    if platform_auth_only_option?
      t('errors.two_factor_auth_setup.must_select_additional_option')
    else
      t('errors.two_factor_auth_setup.must_select_option')
    end
  end
end
