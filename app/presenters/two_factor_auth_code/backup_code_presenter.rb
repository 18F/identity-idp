# frozen_string_literal: true

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

    def troubleshooting_options
      [
        choose_another_method_troubleshooting_option,
        BlockLinkComponent.new(
          url: MarketingSite.help_center_article_url(
            category: 'trouble-signing-in',
            article: 'authentication/issues-with-backup-codes',
          ),
          new_tab: true,
        ).with_content(t('instructions.mfa.backup_code.issues_with_backup_codes')),
        how_add_or_change_authenticator_troubleshooting_option,
      ]
    end
  end
end
