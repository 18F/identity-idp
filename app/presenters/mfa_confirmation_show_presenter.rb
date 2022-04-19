class MfaConfirmationShowPresenter
  include ActionView::Helpers::TranslationHelper
  attr_reader :current_user, :final_path, :next_path
  def initialize(current_user:, next_path:, final_path:)
    @current_user = MfaContext.new(current_user)
    @final_path = final_path
    @next_path = next_path
  end

  def title
    if enabled_method_count > 1
      t(
        'titles.mfa_setup.multiple_authentication_methods_setup',
        method_count: method_count_text,
      )
    else
      t('titles.mfa_setup.first_authentication_method')
    end
  end

  def info
    t('multi_factor_authentication.account_info', count: enabled_method_count)
  end

  private

  def enabled_method_count
    current_user.enabled_mfa_methods_count
  end

  def method_count_text
    t('multi_factor_authentication.current_method_count')[enabled_method_count - 1]
  end
end
