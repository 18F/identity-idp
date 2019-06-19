class PhoneSetupPresenter
  include ActionView::Helpers::TranslationHelper

  attr_reader :otp_delivery_preference

  def initialize(current_user, otp_delivery_preference)
    @current_user = current_user
    @otp_delivery_preference = otp_delivery_preference
  end

  def step
    no_factors_enabled? ? '3' : '4'
  end

  def heading
    t("titles.phone_setup.#{otp_delivery_preference}")
  end

  def label
    t("two_factor_authentication.phone_#{otp_delivery_preference}_label")
  end

  def info
    t("two_factor_authentication.phone_#{otp_delivery_preference}_info_html")
  end

  def image
    "2FA-#{otp_delivery_preference}.svg"
  end

  private

  def no_factors_enabled?
    MfaPolicy.new(@current_user).no_factors_enabled?
  end
end
