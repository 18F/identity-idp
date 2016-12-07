module Users
  class TotpSetupController < ApplicationController
    before_action :confirm_two_factor_authenticated

    def new
      user_session[:new_totp_secret] = current_user.generate_totp_secret if new_totp_secret.nil?

      @qrcode = decorated_user.qrcode(new_totp_secret)
    end

    def confirm
      result = TotpSetupForm.new(current_user, new_totp_secret, params[:code].strip).submit

      analytics.track_event(Analytics::TOTP_SETUP, result)

      if result[:success]
        current_user.save!
        process_valid_code
      else
        process_invalid_code
      end
    end

    def disable
      if current_user.totp_enabled?
        analytics.track_event(Analytics::TOTP_USER_DISABLED)
        create_user_event(:authenticator_disabled)
        current_user.update(otp_secret_key: nil)
        flash[:success] = t('notices.totp_disabled')
      end
      redirect_to profile_path
    end

    private

    def process_valid_code
      create_user_event(:authenticator_enabled)
      flash[:success] = t('notices.totp_configured')
      redirect_to profile_path
      user_session.delete(:new_totp_secret)
    end

    def process_invalid_code
      flash[:error] = t('errors.invalid_totp')
      redirect_to authenticator_setup_path
    end

    def new_totp_secret
      user_session[:new_totp_secret]
    end
  end
end
