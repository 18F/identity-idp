class PhoneSetupPresenter
  include ActionView::Helpers::TranslationHelper

  def heading
    t('titles.phone_setup')
  end

  def label
    t('two_factor_authentication.phone_label')
  end

  def info
    t('two_factor_authentication.phone_info_html')
  end

  def image
    '2FA-voice.svg'
  end
end
