class PhoneSetupPresenter
  include ActionView::Helpers::TranslationHelper

  attr_reader :otp_delivery_preference

  def initialize(otp_delivery_preference)
    @otp_delivery_preference = otp_delivery_preference
  end

  def heading
    t("titles.phone_setup.#{otp_delivery_preference}")
  end

  def label
    t("devise.two_factor_authentication.phone_#{otp_delivery_preference}_label")
  end

  def info
    t("devise.two_factor_authentication.phone_#{otp_delivery_preference}_info_html")
  end

  def image
    "2FA-#{otp_delivery_preference}.svg"
  end
end
