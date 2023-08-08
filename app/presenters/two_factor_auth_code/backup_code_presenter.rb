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

    def redirect_location_step
      :backup_code_verification
    end
  end
end
