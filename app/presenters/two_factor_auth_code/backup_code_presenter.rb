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
  end
end
