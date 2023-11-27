module TwoFactorAuthCode
  class SmsOptInPresenter < GenericDeliveryPresenter
    def initialize; end

    def redirect_location_step
      :sms_opt_in
    end
  end
end
