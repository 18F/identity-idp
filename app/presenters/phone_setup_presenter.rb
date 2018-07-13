class PhoneSetupPresenter
  include Rails.application.routes.url_helpers
  include ActionView::Helpers::TranslationHelper

  attr_reader :user
  delegate :otp_delivery_preference, :two_factor_enabled?, to: :user

  def initialize(user)
    @user = user
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

  def cancel_path
    if two_factor_enabled?([:piv_cac])
      account_recovery_setup_path
    else
      two_factor_options_path
    end
  end
end
