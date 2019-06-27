class PhoneSetupPresenter < SetupPresenter
  include ActionView::Helpers::TranslationHelper

  attr_reader :otp_delivery_preference

  def initialize(current_user, user_fully_authenticated, otp_delivery_preference)
    @current_user = current_user
    @user_fully_authenticated = user_fully_authenticated
    @otp_delivery_preference = otp_delivery_preference
  end

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
