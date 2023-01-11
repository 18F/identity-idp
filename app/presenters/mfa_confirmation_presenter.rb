class MfaConfirmationPresenter
  attr_reader :user

  def initialize(user)
    @user = user
  end

  def heading
    I18n.t('titles.mfa_setup.suggest_second_mfa')
  end

  def info
    I18n.t('mfa.account_info')
  end

  def button
    I18n.t('mfa.add')
  end

  def first_mfa_method
    return if user_mfa_context.blank?
    return :phone if user_mfa_context.phone_configurations.any?
    return :piv_cac if user_mfa_context.piv_cac_configurations.any?
    return :auth_app if user_mfa_context.auth_app_configurations.any?
    return :backup_code if user_mfa_context.backup_code_configurations.any?
    return :webauthn_platform if user_mfa_context.webauthn_platform_configurations.any?
    return :webauthn if user_mfa_context.webauthn_roaming_configurations.any?
  end

  private

  def user_mfa_context
    return @user_mfa_context if defined?(@user_mfa_context)
    @user_mfa_context = MfaContext.new(user) if user
  end
end
