module TwoFactorAuthCode
  class BackupCodePresenter < TwoFactorAuthCode::GenericDeliveryPresenter
    include ActionView::Helpers::TranslationHelper

    def help_text
      ''
    end

    def cancel_link
      reauthn ? account_path : sign_out_path
    end

    def fallback_question
      t('two_factor_authentication.backup_code_fallback.question')
    end
  end
end
