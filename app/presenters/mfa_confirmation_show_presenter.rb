class MfaConfirmationShowPresenter
  include ActionView::Helpers::TranslationHelper
  attr_reader :current_user, :final_path, :next_path
  def initialize(current_user:, next_path:, final_path:)
    @current_user = MfaContext.new(current_user)
    @final_path = final_path
    @next_path = next_path
  end

  def title
    if current_user.enabled_mfa_methods_count > 1
      t(
        'titles.mfa_setup.multiple_authentication_methods_setup',
        method_count: current_user.enabled_mfa_methods_count.ordinalize,
      )
    else
      t('titles.mfa_setup.first_authentication_method')
    end
  end

  def info
    if current_user.enabled_mfa_methods_count > 1
      t('multi_factor_authentication.account_secure')
    else
      t('multi_factor_authentication.cta')
    end
  end
end
