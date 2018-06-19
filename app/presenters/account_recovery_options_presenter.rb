class AccountRecoveryOptionsPresenter
  include ActionView::Helpers::TranslationHelper

  AVAILABLE_2FA_TYPES = %w[sms voice].freeze

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

  def options
    AVAILABLE_2FA_TYPES.map do |type|
      OpenStruct.new(
        type: type,
        label: t("devise.two_factor_authentication.two_factor_choice_options.#{type}"),
        info: t("devise.two_factor_authentication.two_factor_choice_options.#{type}_info"),
        selected: type == :sms
      )
    end
  end
end
