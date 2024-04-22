# frozen_string_literal: true

module TwoFactorAuthentication
  class WebauthnEditPresenter
    include ActionView::Helpers::TranslationHelper

    attr_reader :configuration

    delegate :platform_authenticator?, to: :configuration

    def initialize(configuration:)
      @configuration = configuration
    end

    def heading
      if platform_authenticator?
        t('two_factor_authentication.webauthn_platform.edit_heading')
      else
        t('two_factor_authentication.webauthn_roaming.edit_heading')
      end
    end

    def nickname_field_label
      if platform_authenticator?
        t('two_factor_authentication.webauthn_platform.nickname')
      else
        t('two_factor_authentication.webauthn_roaming.nickname')
      end
    end

    def rename_button_label
      if platform_authenticator?
        t('two_factor_authentication.webauthn_platform.change_nickname')
      else
        t('two_factor_authentication.webauthn_roaming.change_nickname')
      end
    end

    def delete_button_label
      if platform_authenticator?
        t('two_factor_authentication.webauthn_platform.delete')
      else
        t('two_factor_authentication.webauthn_roaming.delete')
      end
    end

    def rename_success_alert_text
      if platform_authenticator?
        t('two_factor_authentication.webauthn_platform.renamed')
      else
        t('two_factor_authentication.webauthn_roaming.renamed')
      end
    end

    def delete_success_alert_text
      if platform_authenticator?
        t('two_factor_authentication.webauthn_platform.deleted')
      else
        t('two_factor_authentication.webauthn_roaming.deleted')
      end
    end
  end
end
