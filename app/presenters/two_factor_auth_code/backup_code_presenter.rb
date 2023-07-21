module TwoFactorAuthCode
  class BackupCodePresenter < TwoFactorAuthCode::GenericDeliveryPresenter
    include ActionView::Helpers::TranslationHelper

    def cancel_link
      if reauthn
        account_path
      else
        sign_out_path
      end
    end

    def fallback_question
      t('two_factor_authentication.backup_code_fallback.question')
    end
  end
end
