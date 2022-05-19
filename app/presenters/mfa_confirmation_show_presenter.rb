class MfaConfirmationShowPresenter
  include ActionView::Helpers::TranslationHelper
  attr_reader :final_path, :next_path, :suggest_second_mfa
  def initialize(final_path:, suggest_second_mfa: false)
    @next_path = next_path
    @suggest_second_mfa = suggest_second_mfa
  end

  def title
    t('titles.mfa_setup.suggest_second_mfa')
  end

  def info
    t('mfa.account_info')
  end
end
