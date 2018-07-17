module TwoFactorAuthCode
  class PersonalKeyPresenter < TwoFactorAuthCode::GenericDeliveryPresenter
    def initialize; end

    def help_text
      ''
    end

    def fallback_question
      t('two_factor_authentication.personal_key_fallback.question')
    end
  end
end
