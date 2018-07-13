module Users
  class TotpSetupController < ApplicationController
    before_action :authenticate_user!
    before_action :confirm_two_factor_authenticated, if: :two_factor_enabled?

    def new
      return redirect_to account_url if configuration_manager.enabled?

      track_event
      store_totp_secret_in_session

      @code = new_totp_secret
      @qrcode = current_user.decorate.qrcode(new_totp_secret)
    end

    def confirm
      result = TotpSetupForm.new(current_user, new_totp_secret, params[:code].strip).submit

      analytics.track_event(Analytics::TOTP_SETUP, result.to_h)

      if result.success?
        process_valid_code
      else
        process_invalid_code
      end
    end

    def disable
      if configuration_manager.enabled?
        analytics.track_event(Analytics::TOTP_USER_DISABLED)
        configuration_manager.remove_configuration
        flash[:success] = t('notices.totp_disabled')
      end
      redirect_to account_url
    end

    private

    delegate :two_factor_enabled?, to: :current_user

    def track_event
      properties = { user_signed_up: two_factor_enabled? }
      analytics.track_event(Analytics::TOTP_SETUP_VISIT, properties)
    end

    def store_totp_secret_in_session
      user_session[:new_totp_secret] = configuration_manager.generate_secret if new_totp_secret.nil?
    end

    def process_valid_code
      mark_user_as_fully_authenticated
      flash[:success] = t('notices.totp_configured')
      redirect_to url_after_entering_valid_code
      user_session.delete(:new_totp_secret)
    end

    def mark_user_as_fully_authenticated
      user_session[TwoFactorAuthentication::NEED_AUTHENTICATION] = false
      user_session[:authn_at] = Time.zone.now
    end

    def url_after_entering_valid_code
      if current_user.decorate.should_acknowledge_personal_key?(user_session)
        sign_up_personal_key_url
      else
        account_url
      end
    end

    def process_invalid_code
      flash[:error] = t('errors.invalid_totp')
      redirect_to authenticator_setup_url
    end

    def new_totp_secret
      user_session[:new_totp_secret]
    end

    def configuration_manager
      @configuration_manager ||= current_user.two_factor_configuration(:totp)
    end
  end
end
