# frozen_string_literal: true

module TwoFactorAuthCode
  class MaxAttemptsReachedPresenter
    include ActionView::Helpers::TranslationHelper

    attr_reader :type, :user

    def initialize(type, user)
      @type = type
      @user = user
    end

    def locked_reason
      case type.to_s
      when 'backup_code_login_attempts'
        t('two_factor_authentication.max_backup_code_login_attempts_reached')
      when 'generic_login_attempts'
        t('two_factor_authentication.max_generic_login_attempts_reached')
      when 'otp_login_attempts'
        t('two_factor_authentication.max_otp_login_attempts_reached')
      when 'otp_requests'
        t('two_factor_authentication.max_otp_requests_reached')
      when 'totp_login_attempts'
        t('two_factor_authentication.max_otp_login_attempts_reached')
      when 'totp_requests'
        t('two_factor_authentication.max_otp_requests_reached')
      when 'personal_key_login_attempts'
        t('two_factor_authentication.max_personal_key_login_attempts_reached')
      when 'piv_cac_login_attempts'
        t('two_factor_authentication.max_piv_cac_login_attempts_reached')
      else
        raise "Unsupported description type: #{type}"
      end
    end
  end
end
