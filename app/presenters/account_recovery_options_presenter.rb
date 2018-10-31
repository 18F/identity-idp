class AccountRecoveryOptionsPresenter < TwoFactorOptionsPresenter
  include ActionView::Helpers::TranslationHelper

  def title
    t('titles.account_recovery_setup')
  end

  def heading
    t('headings.account_recovery_setup.piv_cac_linked')
  end

  def info
    t('instructions.account_recovery_setup.piv_cac_next_step')
  end

  def label
    t('forms.account_recovery_setup.legend') + ':'
  end
end
