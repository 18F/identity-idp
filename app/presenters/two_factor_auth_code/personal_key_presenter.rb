module TwoFactorAuthCode
  class PersonalKeyPresenter < TwoFactorAuthCode::GenericDeliveryPresenter
    def initialize; end

    def redirect_location_step
      :personal_key_verification
    end
  end
end
