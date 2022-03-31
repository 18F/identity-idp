module TwoFactorAuthCode
  class MaxAttemptsReachedPresenter < FailurePresenter
    include ActionView::Helpers::TranslationHelper
    include ActionView::Helpers::UrlHelper

    attr_reader :type, :decorated_user

    def initialize(type, decorated_user)
      super(:locked)
      @type = type
      @decorated_user = decorated_user
    end

    def title
      t('titles.account_locked')
    end

    def header
      t('titles.account_locked')
    end

    def description(view_context)
      [locked_reason, please_try_again(view_context)]
    end

    def troubleshooting_options
      [read_about_two_factor_authentication, contact_support]
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
      when 'personal_key_login_attempts'
        t('two_factor_authentication.max_personal_key_login_attempts_reached')
      when 'piv_cac_login_attempts'
        t('two_factor_authentication.max_piv_cac_login_attempts_reached')
      else
        raise "Unsupported description type: #{type}"
      end
    end

    def please_try_again(view_context)
      t(
        'two_factor_authentication.please_try_again_html',
        countdown: view_context.render(
          CountdownComponent.new(expiration: decorated_user.lockout_time_expiration),
        ),
      )
    end

    def read_about_two_factor_authentication
      {
        text: t('two_factor_authentication.read_about_two_factor_authentication'),
        url: MarketingSite.help_url,
        new_tab: true,
      }
    end

    def contact_support
      {
        url: MarketingSite.contact_url,
        text: t('idv.troubleshooting.options.contact_support', app_name: APP_NAME),
        new_tab: true,
      }
    end
  end
end
